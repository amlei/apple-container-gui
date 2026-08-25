const $ = s => document.querySelector(s);
const $$ = s => [...document.querySelectorAll(s)];
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const icon = (n, cls = '') => n ? `<svg class="${cls}" aria-hidden="true"><use href="#i-${n}"/></svg>` : '';
const GB = 1073741824;

const fmtBytes = b => {
  if (b == null) return '—';
  const u = ['B', 'KB', 'MB', 'GB', 'TB'];
  let i = 0, n = b;
  while (n >= 1024 && i < u.length - 1) { n /= 1024; i++; }
  return `${n >= 100 || i === 0 ? Math.round(n) : n.toFixed(1)} ${u[i]}`;
};
const relTime = ts => {
  if (!ts) return '—';
  const diff = Date.now() - ts;
  const m = Math.floor(diff / 60000);
  if (m < 1) return t('time.now');
  if (m < 60) return t('time.min', { n: m });
  const h = Math.floor(m / 60);
  if (h < 24) return t('time.hour', { n: h });
  return t('time.day', { n: Math.floor(h / 24) });
};
const fmtDur = ms => {
  const s = Math.max(1, Math.floor(ms / 1000));
  if (s < 60) return t('dur.s', { n: s });
  const m = Math.floor(s / 60);
  if (m < 60) return t('dur.m', { n: m, s: s % 60 });
  const h = Math.floor(m / 60);
  if (h < 24) return t('dur.h', { n: h, m: m % 60 });
  return t('dur.d', { n: Math.floor(h / 24), h: h % 24 });
};
const fmtDate = ts => new Date(ts).toLocaleString(I18N.locale(), { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });

const S = {
  route: 'overview',
  ctFilter: 'all', ctSearch: '',
  imgSearch: '', volSearch: '',
  drawerTab: 'info',
  netNoteDismissed: false,
  k8sNoteDismissed: false,
  syslogFollow: true, syslogRange: '5m'
};

const VIEWS = {};

const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));
const rnd = (lo, hi) => lo + Math.random() * (hi - lo);

const seedHist = (base, jit, min = 0) =>
  Array.from({ length: 60 }, () => clamp(base + rnd(-jit, jit), min, Infinity));

function initStats(c) {
  if (!c.hist) {
    const running = c.status === 'running';
    c.hist = {
      cpu: seedHist(running ? c.cpuPct : 0, running ? c.cpuPct * 0.4 + 0.3 : 0),
      mem: seedHist(running ? c.memBytes : 0, running ? c.memBytes * 0.05 : 0),
      rx: seedHist(running ? c.rxRate : 0, running ? c.rxRate * 0.5 : 0),
      tx: seedHist(running ? c.txRate : 0, running ? c.txRate * 0.5 : 0)
    };
  }
}

setInterval(() => {
  Mock.containers.forEach(c => {
    if (!c.hist) initStats(c);
    if (c.status !== 'running') return;
    c.cpuPct = clamp(c.cpuPct + rnd(-0.7, 0.7), 0.1, c.cpus * 40);
    c.memBytes = clamp(c.memBytes + rnd(-3e6, 3e6), c.memLimit * 0.08, c.memLimit * 0.92);
    c.rxRate = clamp(c.rxRate + rnd(-8000, 8000), 200, 500000);
    c.txRate = clamp(c.txRate + rnd(-9000, 9000), 200, 500000);
    ['cpu', 'mem', 'rx', 'tx'].forEach(k => {
      const arr = c.hist[k];
      arr.push(k === 'cpu' ? c.cpuPct : k === 'mem' ? c.memBytes : k === 'rx' ? c.rxRate : c.txRate);
      if (arr.length > 60) arr.shift();
    });
  });
}, 1000);

function drawSeries(cv, series, color, unitFmt) {
  const dpr = window.devicePixelRatio || 1;
  const w = cv.clientWidth, h = cv.clientHeight;
  if (!w || !h) return;
  cv.width = w * dpr; cv.height = h * dpr;
  const ctx = cv.getContext('2d');
  ctx.scale(dpr, dpr);
  const max = Math.max(...series, 0.0001) * 1.15;
  const px = i => (i / (series.length - 1)) * w;
  const py = v => h - (v / max) * (h - 4) - 2;
  ctx.beginPath();
  series.forEach((v, i) => i === 0 ? ctx.moveTo(px(0), py(v)) : ctx.lineTo(px(i), py(v)));
  ctx.strokeStyle = color; ctx.lineWidth = 1.6; ctx.lineJoin = 'round'; ctx.stroke();
  ctx.lineTo(w, h); ctx.lineTo(0, h); ctx.closePath();
  ctx.globalAlpha = 0.12; ctx.fillStyle = color; ctx.fill();
}

let overlayStack = [];
function makeLayer(inner) {
  const wrap = document.createElement('div');
  wrap.appendChild(Object.assign(document.createElement('div'), { className: 'overlay-scrim' }));
  wrap.insertAdjacentHTML('beforeend', inner);
  $('#overlay-root').appendChild(wrap);
  overlayStack.push(wrap);
  return wrap;
}
function dropLayer(wrap) {
  overlayStack = overlayStack.filter(x => x !== wrap);
  wrap.remove();
}
function openSheet(html, { wide = false } = {}) {
  const wrap = makeLayer(`<div class="sheet${wide ? ' wide' : ''}" role="dialog">${html}</div>`);
  const sheetEl = wrap.querySelector('.sheet');
  const close = () => {
    if (wrap.dataset.closing) return;
    wrap.dataset.closing = '1';
    wrap.querySelector('.overlay-scrim').style.opacity = '0';
    wrap.querySelector('.overlay-scrim').style.transition = 'opacity 190ms ease-in';
    sheetEl.classList.add('closing');
    setTimeout(() => dropLayer(wrap), 200);
  };
  sheetEl._close = close;
  wrap._close = close;
  wrap.querySelector('.overlay-scrim').addEventListener('click', close);
  sheetEl.querySelectorAll('[data-close]').forEach(b => b.addEventListener('click', close));
  return { wrap, el: sheetEl, close };
}
function openDrawer(html) {
  const host = document.createElement('div');
  host.className = 'inspector-host';
  host.innerHTML = `<div class="drawer" role="dialog">${html}</div>`;
  $('.main').appendChild(host);
  overlayStack.push(host);
  const dr = host.querySelector('.drawer');
  const close = () => {
    if (host.dataset.closing) return;
    host.dataset.closing = '1';
    dr.classList.add('closing');
    setTimeout(() => {
      host.remove();
      overlayStack = overlayStack.filter(x => x !== host);
    }, 260);
  };
  dr._close = close;
  host._close = close;
  host.addEventListener('click', e => {
    if (e.target.closest('[data-close]')) close();
  });
  return { wrap: host, el: dr, close };
}
function alertBox({ title, msg, confirmLabel, cancelLabel, danger }) {
  return new Promise(res => {
    const wrap = makeLayer(`
      <div class="alert" role="alertdialog">
        <div class="alert-i"><h3>${esc(title)}</h3>${msg ? `<p>${msg}</p>` : ''}</div>
        <div class="alert-b">
          <button data-r="0">${esc(cancelLabel || t('act.cancel'))}</button>
          <button class="${danger ? 'destructive' : ''}" data-r="1">${esc(confirmLabel || t('act.confirm'))}</button>
        </div>
      </div>`);
    const al = wrap.querySelector('.alert');
    const done = v => {
      if (wrap.dataset.closing) return;
      wrap.dataset.closing = '1';
      al.classList.add('closing');
      setTimeout(() => dropLayer(wrap), 190);
      res(v);
    };
    al.querySelector('[data-r="0"]').onclick = () => done(false);
    al.querySelector('[data-r="1"]').onclick = () => done(true);
  });
}
function toast(msg, type = 'ok') {
  const root = $('#toast-root');
  const el = document.createElement('div');
  el.className = `toast ${type}`;
  el.innerHTML = `${icon(type === 'err' ? 'x' : 'check')}<span>${msg}</span>`;
  root.appendChild(el);
  while (root.children.length > 3) root.firstChild.remove();
  setTimeout(() => el.remove(), 2900);
}

let menuEl = null;
function closeMenu() { if (menuEl) { menuEl.remove(); menuEl = null; } }
function showMenu(items, anchor) {
  closeMenu();
  menuEl = document.createElement('div');
  menuEl.className = 'menu';
  menuEl.innerHTML = items.map((it, idx) => {
    if (it === '-') return '<hr>';
    if (it.title) return `<div class="m-title">${esc(it.title)}</div>`;
    return `<button data-mi="${idx}"${it.danger ? ' class="danger"' : ''}${it.disabled ? ' disabled' : ''}>${it.icon ? icon(it.icon) : '<span class="mi-ph"></span>'}<span>${esc(it.label)}</span></button>`;
  }).join('');
  $('#overlay-root').appendChild(menuEl);
  const r = anchor.getBoundingClientRect();
  const mw = menuEl.offsetWidth, mh = menuEl.offsetHeight;
  let x = Math.min(r.right - mw, window.innerWidth - mw - 10);
  let y = r.bottom + 6;
  if (y + mh > window.innerHeight - 10) y = r.top - mh - 6;
  menuEl.style.left = Math.max(10, x) + 'px';
  menuEl.style.top = Math.max(10, y) + 'px';
  menuEl.addEventListener('click', e => {
    const b = e.target.closest('[data-mi]');
    if (!b) return;
    const it = items[+b.dataset.mi];
    closeMenu();
    it.fn && it.fn();
  });
  setTimeout(() => document.addEventListener('pointerdown', outside), 0);
  function outside(e) { if (menuEl && !menuEl.contains(e.target)) { closeMenu(); document.removeEventListener('pointerdown', outside); } }
}

const NAV = [
  { id: 'overview', icon: 'overview', key: 'nav.overview' },
  { id: 'containers', icon: 'box', key: 'nav.containers', badge: () => Mock.containers.filter(c => c.status === 'running').length },
  { id: 'images', icon: 'layers', key: 'nav.images' },
  { id: 'volumes', icon: 'db', key: 'nav.volumes' },
  { id: 'networks', icon: 'globe', key: 'nav.networks' },
  { id: 'machines', icon: 'display', key: 'nav.machines' },
  { id: 'k8s', icon: 'k8s', key: 'nav.k8s' },
  '-',
  { id: 'settings', icon: 'sliders', key: 'nav.settings' }
];

function renderNav() {
  $('#nav').innerHTML = NAV.map(n => {
    if (n === '-') return '<div class="nav-sep"></div>';
    const badge = n.badge ? n.badge() : null;
    return `<button class="nav-item${S.route === n.id ? ' active' : ''}" data-action="nav" data-route="${n.id}">
      ${icon(n.icon)}<span>${t(n.key)}</span>${badge != null ? `<span class="nav-badge">${badge}</span>` : ''}</button>`;
  }).join('');
}

function renderSidebarFoot() {
  const svc = $('#svc-status');
  const running = Mock.system.servicesRunning;
  svc.innerHTML = `<span class="dot ${running ? 'ok pulse' : 'off'}"></span><span>${t(running ? 'svc.running' : 'svc.stopped')}</span>`;
}

const THEME = {
  mode: localStorage.getItem('acg-theme') || 'auto',
  apply() {
    const dark = this.mode === 'dark' || (this.mode === 'auto' && matchMedia('(prefers-color-scheme: dark)').matches);
    document.documentElement.dataset.theme = dark ? 'dark' : 'light';
  },
  current() {
    return this.mode === 'dark' || (this.mode === 'auto' && matchMedia('(prefers-color-scheme: dark)').matches) ? 'dark' : 'light';
  },
  cycle() {
    this.mode = this.mode === 'auto' ? 'light' : this.mode === 'light' ? 'dark' : 'auto';
    localStorage.setItem('acg-theme', this.mode);
    this.apply();
    renderSidebarFoot();
  }
};

function updateBadges() { renderNav(); renderSidebarFoot(); }

function go(route) {
  S.route = route;
  render();
}
function render() {
  renderNav();
  const v = VIEWS[S.route];
  const head = `<header class="page-head"><h1>${t(v.title)}</h1>
    <div class="page-actions">${v.toolbar ? v.toolbar() : ''}</div></header>`;
  $('#view-root').innerHTML = head + v.render();
  v.after && v.after();
}
function rerenderList() {
  const v = VIEWS[S.route];
  const region = $('#list-region');
  if (!region) return render();
  const ae = document.activeElement;
  const fid = ae && ae.getAttribute('fid');
  const pos = ae && ae.selectionStart;
  region.innerHTML = v.list();
  v.afterList && v.afterList();
  if (fid) {
    const el = $(`[fid="${fid}"]`);
    if (el) { el.focus(); try { el.setSelectionRange(pos, pos); } catch (_) {} }
  }
}

const KEYS = (() => {
  const DEFAULTS = {
    'nav.overview': 'Mod+1',
    'nav.containers': 'Mod+2',
    'nav.images': 'Mod+3',
    'nav.volumes': 'Mod+4',
    'nav.networks': 'Mod+5',
    'nav.machines': 'Mod+6',
    'nav.k8s': 'Mod+7',
    'nav.settings': 'Mod+8',
    'focus.search': 'Mod+F',
    'primary.action': 'Mod+N'
  };
  let map = { ...DEFAULTS };
  try {
    const saved = JSON.parse(localStorage.getItem('acg-keymap') || '{}');
    Object.keys(saved).forEach(k => { if (k in DEFAULTS && saved[k]) map[k] = saved[k]; });
  } catch (_) {}
  const save = () => localStorage.setItem('acg-keymap', JSON.stringify(
    Object.fromEntries(Object.keys(DEFAULTS).filter(k => map[k] !== DEFAULTS[k]).map(k => [k, map[k]]))));
  const normKey = k => {
    if (k.length === 1) return k.toUpperCase();
    const named = { Escape: 'Esc', ArrowUp: '↑', ArrowDown: '↓', ArrowLeft: '←', ArrowRight: '→' };
    return named[k] || k;
  };
  const comboFromEvent = e => {
    const p = [];
    if (e.metaKey) p.push('Mod');
    if (e.ctrlKey) p.push('Ctrl');
    if (e.altKey) p.push('Alt');
    if (e.shiftKey) p.push('Shift');
    let k = e.key === ' ' ? 'Space' : e.key;
    if (['Control', 'Meta', 'Alt', 'Shift'].includes(k)) return null;
    p.push(normKey(k));
    return p.join('+');
  };
  const pretty = combo => !combo ? '' : combo.split('+').map(x =>
    ({ Mod: '⌘', Ctrl: '⌃', Alt: '⌥', Shift: '⇧', Esc: 'Esc' }[x] || x)).join('');
  const assign = (action, combo) => {
    const cleared = Object.keys(map).filter(k => k !== action && map[k] === combo);
    cleared.forEach(k => { map[k] = ''; });
    map[action] = combo;
    save();
    return cleared;
  };
  const reset = () => { map = { ...DEFAULTS }; save(); };
  return { DEFAULTS, get map() { return map; }, save, comboFromEvent, pretty, assign, reset };
})();

let recAction = null;
const startRecord = el => {
  recAction = el.dataset.rec;
  el.classList.add('rec');
  const lbl = el.querySelector('.kc-label');
  if (lbl) lbl.textContent = t('keys.recording');
};
const cancelRecord = () => {
  recAction = null;
  $$('.keycap.rec').forEach(el => el.classList.remove('rec'));
  render();
};
