const ACT = {
  nav: el => go(el.dataset.route),
  'cycle-theme': () => THEME.cycle(),
  'toggle-service-quick': () => Mock.system.servicesRunning ? ACT['svc-stop']() : ACT['svc-start'](),
  'svc-stop': async () => {
    if (!await alertBox({ title: t('svc.stopWarnTitle'), msg: esc(t('svc.stopWarnMsg')), confirmLabel: t('confirm.stop'), danger: true })) return;
    Mock.system.servicesRunning = false;
    toast(t('svc.stopped'));
    updateBadges(); render();
  },
  'svc-start': () => {
    Mock.system.servicesRunning = true;
    Mock.system.startedAt = Date.now();
    toast(t('svc.running'));
    updateBadges(); render();
  },
  'ct-filter': el => { S.ctFilter = el.dataset.val; render(); },
  'clear-search': () => {
    if (S.route === 'containers') S.ctSearch = '';
    if (S.route === 'images') S.imgSearch = '';
    if (S.route === 'volumes') S.volSearch = '';
    render();
  },
  'open-run': () => runSheet(),
  'open-pull': () => pullSheet(),
  'open-build': () => buildSheet(),
  'row-open': el => {
    const { kind, id } = el.dataset;
    if (kind === 'container') containerDrawer(id);
    else if (kind === 'image') imageDrawer(id);
    else if (kind === 'volume') volumeDrawer(id);
  },
  'row-menu': el => {
    const { kind, id } = el.dataset;
  if (kind === 'container') { const c = Mock.containers.find(x => x.id === id); c && containerMenu(c); }
  else if (kind === 'image') { const i = Mock.images.find(x => x.ref === id); i && imageMenu(i); }
  else if (kind === 'machine') { const m = Mock.machines.find(x => x.name === id); m && machineMenu(m); }
  else if (kind === 'k8s') { const k = Mock.k8s.find(x => x.name === id); k && k8sMenu(k); }
  },
  copy: el => copyText(el.dataset.copy),
  'sim-export': el => SIM.exportFs(el.dataset.id),
  'ct-start': el => ctLifecycle(el.dataset.id || S.drawerId, 'start'),
  'ct-stop': el => ctLifecycle(el.dataset.id || S.drawerId, 'stop'),
  'ct-kill': el => ctLifecycle(el.dataset.id || S.drawerId, 'kill'),
  'img-run': el => { $$('.drawer').length && document.querySelector('.drawer._close'); runSheet(el.dataset.ref); },
  'img-push': el => SIM.push(el.dataset.ref),
  'img-tag': el => SIM.tagDialog(el.dataset.ref),
  'img-save': el => SIM.saveTar(el.dataset.ref),
  'vol-delete': async el => {
    const v = Mock.volumes.find(x => x.name === el.dataset.id);
    if (!v) return;
    if (v.usedBy.length) { toast(t('del.vol.inuse'), 'err'); return; }
    if (!await alertBox({ title: t('del.vol.title', { n: v.name }), msg: esc(t('del.vol.msg')), confirmLabel: t('confirm.yes'), danger: true })) return;
    Mock.volumes = Mock.volumes.filter(x => x.name !== v.name);
    Mock.df.volumes.count--;
    toast(v.name + ' · ' + t('act.delete'));
    updateBadges(); render();
  },
  'open-vol-new': () => {
    if (!requireSvc()) return;
    const { el } = openSheet(`
      <div class="sheet-h"><h2>${t('vol.new.title')}</h2><button class="icon-btn ghost" data-close>${icon('x')}</button></div>
      <div class="sheet-b">
        <div class="form-group"><label class="form-label">${t('vol.new.name')} *</label><input class="field mono" id="vn-name" placeholder="${t('vol.new.name.ph')}"></div>
        <div class="form-row">
          <div class="form-group"><label class="form-label">${t('vol.new.size')}</label>
            <span style="display:flex;gap:6px"><input class="field num" id="vn-size" type="number" min="0" step="any" placeholder="10">
            <select class="field" id="vn-unit" style="width:86px;flex:none"><option>GB</option><option>MB</option><option>TB</option></select></span></div>
          <div class="form-group"><label class="form-label">${t('vol.new.journal')}</label>
            <select class="field" id="vn-journal">
              <option value="">${t('journal.none')}</option>
              <option value="ordered">${t('journal.ordered')}</option>
              <option value="writeback">${t('journal.writeback')}</option>
              <option value="journal">${t('journal.journal')}</option>
            </select></div>
        </div>
      </div>
      ${sheetFooter(t('act.cancel'), t('act.create'))}`);
    const submit = () => {
      const name = el.querySelector('#vn-name').value.trim();
      if (!name) return toast(t('run.err.image'), 'err');
      if (Mock.volumes.some(v => v.name === name)) return toast(t('set.dns.exists'), 'err');
      const n = parseFloat(el.querySelector('#vn-size').value);
      const unit = { GB: GB, MB: 1048576, TB: 1024 * GB }[el.querySelector('#vn-unit').value];
      Mock.volumes.unshift({ name, driver: 'local', size: n > 0 ? Math.round(n * unit) : null,
        journal: el.querySelector('#vn-journal').value || null, usedBy: [], created: Date.now() });
      Mock.df.volumes.count++;
      close();
      toast(name + ' · ' + t('vol.new.title'));
      updateBadges();
      if (S.route !== 'volumes') go('volumes'); else render();
    };
    el.querySelector('#sheet-submit').addEventListener('click', submit);
    el.querySelector('#vn-name').focus();
  },
  'net-delete': async el => {
    const n = Mock.networks.find(x => x.name === el.dataset.id);
    if (!n || n.system) { toast(t('del.net.system'), 'err'); return; }
    if (!await alertBox({ title: t('del.net.title', { n: n.name }), msg: esc(t('del.net.msg')), confirmLabel: t('confirm.yes'), danger: true })) return;
    Mock.networks = Mock.networks.filter(x => x.name !== n.name);
    toast(n.name + ' · ' + t('act.delete'));
    render();
  },
  'dismiss-note': () => { S.netNoteDismissed = true; render(); },
  'open-net-new': () => {
    if (!requireSvc()) return;
    const { el } = openSheet(`
      <div class="sheet-h"><h2>${t('net.new.title')}</h2><button class="icon-btn ghost" data-close>${icon('x')}</button></div>
      <div class="sheet-b">
        <div class="form-group"><label class="form-label">${t('net.new.name')} *</label><input class="field mono" id="nn-name" placeholder="${t('net.new.name.ph')}"></div>
        <div class="form-group"><label class="form-label">${t('net.subnet4')}</label><input class="field mono" id="nn-s4" placeholder="${t('net.new.sub4.ph')}"></div>
        <div class="form-group"><label class="form-label">${t('net.subnet6')}</label><input class="field mono" id="nn-s6" placeholder="${t('net.new.sub6.ph')}"></div>
        <label class="check-row"><span class="switch"><input type="checkbox" id="nn-internal"><i></i></span><span>${t('net.new.internal')}</span></label>
      </div>
      ${sheetFooter(t('act.cancel'), t('act.create'))}`);
    const submit = () => {
      const name = el.querySelector('#nn-name').value.trim();
      if (!name) return toast(t('run.err.image'), 'err');
      Mock.networks.push({
        name, subnet4: el.querySelector('#nn-s4').value.trim() || `192.168.${100 + Mock.networks.length}.0/24`,
        subnet6: el.querySelector('#nn-s6').value.trim() || null,
        internal: el.querySelector('#nn-internal').checked, system: false, attached: []
      });
      close();
      toast(name + ' · ' + t('net.new.title'));
      if (S.route !== 'networks') go('networks'); else render();
    };
    el.querySelector('#sheet-submit').addEventListener('click', submit);
    el.querySelector('#nn-name').focus();
  },
  'mach-setdef': el => {
    Mock.machines.forEach(m => m.isDefault = m.name === el.dataset.id);
    toast(t('mach.setdef.ok', { n: el.dataset.id }));
    rerenderList();
  },
  'mach-stop': async el => {
    const m = Mock.machines.find(x => x.name === el.dataset.id);
    if (!m) return;
    if (!await alertBox({ title: t('mach.stop.title', { n: m.name }), confirmLabel: t('confirm.stop'), danger: true })) return;
    m.state = 'stopped';
    toast(`${m.name} · ${t('act.stop')}`);
    rerenderList();
  },
  'mach-start': el => {
    if (!requireSvc()) return;
    const m = Mock.machines.find(x => x.name === el.dataset.id);
    if (!m) return;
    m.state = 'running';
    toast(`${m.name} · ${t('act.start')}`);
    rerenderList();
  },
  'mach-shell': el => machineShellDrawer(el.dataset.id),
  'open-mach-new': () => machNewSheet(),
  'dismiss-k8-note': () => { S.k8sNoteDismissed = true; render(); },
  'open-k8-new': () => k8sCreateSheet(),
  'k8-start': src => {
    if (!requireSvc()) return;
    const name = typeof src === 'string' ? src : src.dataset.id;
    const k = Mock.k8s.find(x => x.name === name);
    if (!k) return;
    k.state = 'running';
    toast(`${k.name} · ${t('st.running')}`);
    rerenderList();
  },
  'k8-loadimg': el => {
    const k = Mock.k8s.find(x => x.name === el.dataset.id);
    if (!k || !requireSvc() || k.state !== 'running') return;
    k8sLoadImageSheet(k.name);
  },
  'maintain-menu': el => showMenu([
    { title: t('act.maintain') },
    { icon: 'box', label: t('act.pruneContainers'), fn: () => pruneContainers() },
    '-',
    { icon: 'layers', label: t('act.pruneDangling'), fn: () => pruneImages(false) },
    { icon: 'layers', label: t('act.pruneUnusedImages'), fn: () => pruneImages(true) },
    '-',
    { icon: 'db', label: t('act.pruneVolumes'), fn: () => pruneVolumes() },
    { icon: 'globe', label: t('act.pruneNetworks'), fn: () => pruneNetworks() }
  ], el),
  'kernel-rec': () => {
    toast(t('set.kernel.installing'));
    setTimeout(() => {
      Mock.system.kernel.path = 'opt/kata/share/kata-containers/vmlinux-6.19.2-104-release';
      toast(t('set.kernel.ok'));
      render();
    }, 1700);
  },
  'kernel-custom': () => {
    const { el } = openSheet(`
      <div class="sheet-h"><h2>${t('act.customKernel')}</h2><button class="icon-btn ghost" data-close>${icon('x')}</button></div>
      <div class="sheet-b">
        <div class="form-group"><label class="form-label">${t('mach.cfg.kernel')}</label>
          <input class="field mono" id="kc-path" placeholder="/path/to/vmlinux"></div>
        <p class="hint">${t('mach.cfg.kernel.ph')}</p>
      </div>
      ${sheetFooter(t('act.cancel'), t('act.save'))}`);
    el.querySelector('#sheet-submit').addEventListener('click', () => {
      const p = el.querySelector('#kc-path').value.trim();
      if (p) Mock.system.kernel.path = p.replace(/^~\//, '');
      close();
      toast(p ? p.split('/').pop() : t('act.save'));
      render();
    });
  },
  'dns-add': () => {
    const input = $('#dns-input');
    const d = input.value.trim().replace(/^\*\./, '');
    if (!d) return;
    if (Mock.dnsDomains.includes(d)) return toast(t('set.dns.exists'), 'err');
    Mock.dnsDomains.push(d);
    Mock.props.dns.domain = `"${d}"`;
    toast(`*.${d} · /etc/resolver/${d}`);
    render();
  },
  'dns-del': async el => {
    if (!await alertBox({ title: `${el.dataset.id}`, msg: esc('/etc/resolver/' + el.dataset.id), confirmLabel: t('confirm.yes'), danger: true })) return;
    Mock.dnsDomains = Mock.dnsDomains.filter(d => d !== el.dataset.id);
    toast(el.dataset.id + ' · ' + t('act.remove'));
    render();
  },
  'reg-login': () => {
    const { el } = openSheet(`
      <div class="sheet-h"><h2>${t('set.reg.login.title')}</h2><button class="icon-btn ghost" data-close>${icon('x')}</button></div>
      <div class="sheet-b">
        <div class="form-group"><label class="form-label">${t('set.reg.login.server')} *</label><input class="field mono" id="rl-server" placeholder="${t('set.reg.login.server.ph')}"></div>
        <div class="form-row">
          <div class="form-group"><label class="form-label">${t('set.reg.login.user')}</label><input class="field" id="rl-user" autocomplete="off"></div>
          <div class="form-group"><label class="form-label">${t('set.reg.login.pass')}</label><input class="field" type="password" id="rl-pass" autocomplete="new-password"></div>
        </div>
        <p class="hint">${t('set.reg.desc')}</p>
      </div>
      ${sheetFooter(t('act.cancel'), t('act.login'), 'key')}`);
    const submit = () => {
      const server = el.querySelector('#rl-server').value.trim();
      if (!server) return;
      Mock.registries.push({ server, user: el.querySelector('#rl-user').value.trim() || '—', scheme: 'auto' });
      close();
      toast(server + ' · ' + t('act.login'));
      render();
    };
    el.querySelector('#sheet-submit').addEventListener('click', submit);
    el.querySelector('#rl-server').focus();
  },
  'reg-logout': async el => {
    if (!await alertBox({ title: el.dataset.id, msg: esc(t('set.reg.desc')), confirmLabel: t('confirm.logout'), danger: true })) return;
    Mock.registries = Mock.registries.filter(r => r.server !== el.dataset.id);
    toast(el.dataset.id + ' · ' + t('act.logout'));
    render();
  },
  'open-syslogs': () => syslogsDrawer(),
  'set-theme': el => {
    THEME.mode = el.dataset.val;
    localStorage.setItem('acg-theme', THEME.mode);
    THEME.apply();
    render();
  },
  'rec-start': el => startRecord(el),
  'keys-reset': () => { KEYS.reset(); render(); toast(t('keys.saved')); }
};

function runPrimary() {
  switch (S.route) {
    case 'containers': ACT['open-run'](); return true;
    case 'images': ACT['open-pull'](); return true;
    case 'volumes': ACT['open-vol-new'](); return true;
    case 'networks': ACT['open-net-new'](); return true;
    case 'machines': machNewSheet(); return true;
    case 'k8s': k8sCreateSheet(); return true;
    case 'overview': go('containers'); return true;
    default: return false;
  }
}
function runShortcut(act) {
  if (act.startsWith('nav.')) { go(act.slice(4)); return true; }
  if (act === 'focus.search') {
    const inp = $('[fid^="s-"]');
    if (!inp) return false;
    inp.focus();
    if (inp.select) inp.select();
    return true;
  }
  if (act === 'primary.action') return runPrimary();
  return false;
}
const handleRec = e => {
  e.preventDefault();
  e.stopPropagation();
  const action = recAction;
  if (!action) return;
  if (e.key === 'Escape') { cancelRecord(); return; }
  const combo = KEYS.comboFromEvent(e);
  if (!combo) return;
  const ok = /^(Mod|Ctrl|Alt)\+/.test(combo) || /F\d{1,2}$/.test(combo.split('+').pop());
  if (!ok) { toast(t('keys.needmod'), 'err'); cancelRecord(); return; }
  const cleared = KEYS.assign(action, combo);
  recAction = null;
  toast(cleared.length ? t('keys.reassigned', { c: KEYS.pretty(combo) }) : t('keys.saved'));
  render();
};

async function pruneContainers() {
  const stopped = Mock.containers.filter(c => c.status !== 'running');
  if (!stopped.length) return toast(t('prune.ct.ok', { n: 0, size: fmtBytes(0) }));
  if (!await alertBox({ title: t('prune.ct.title'), confirmLabel: t('confirm.prune'), danger: true })) return;
  Mock.containers = Mock.containers.filter(c => c.status === 'running');
  const size = stopped.length * rnd(40e6, 200e6);
  Mock.df.containers.count -= stopped.length;
  toast(t('prune.ct.ok', { n: stopped.length, size: fmtBytes(size) }));
  updateBadges(); render();
}
async function pruneImages(all) {
  const victims = Mock.images.filter(i => !i.usedBy.length && (all || i.dangling));
  const key = all ? 'prune.imga' : 'prune.imgd';
  if (!victims.length) return toast(t(key + '.ok', { n: 0, size: fmtBytes(0) }));
  if (all && !await alertBox({ title: t('prune.imga.title'), msg: esc(t('prune.imga.msg')), confirmLabel: t('confirm.prune'), danger: true })) return;
  if (!all && !await alertBox({ title: t('prune.imgd.title'), confirmLabel: t('confirm.prune'), danger: true })) return;
  const size = victims.reduce((a, b) => a + b.size, 0);
  Mock.images = Mock.images.filter(i => !victims.includes(i));
  Mock.df.images.count -= victims.length;
  toast(t(key + '.ok', { n: victims.length, size: fmtBytes(size) }));
  updateBadges(); render();
}
async function pruneVolumes() {
  const unused = Mock.volumes.filter(v => !v.usedBy.length);
  if (!unused.length) return toast(t('prune.vol.ok', { n: 0, size: fmtBytes(0) }));
  if (!await alertBox({ title: t('prune.vol.title'), confirmLabel: t('confirm.prune'), danger: true })) return;
  const size = unused.reduce((a, v) => a + (v.size || 0), 0);
  Mock.volumes = Mock.volumes.filter(v => v.usedBy.length);
  Mock.df.volumes.count -= unused.length;
  toast(t('prune.vol.ok', { n: unused.length, size: fmtBytes(size) }));
  updateBadges(); render();
}
async function pruneNetworks() {
  const unused = Mock.networks.filter(n => !n.system && !n.attached.length);
  if (!unused.length) return toast(t('prune.net.ok', { n: 0 }));
  if (!await alertBox({ title: t('prune.net.title'), confirmLabel: t('confirm.prune'), danger: true })) return;
  Mock.networks = Mock.networks.filter(n => n.system || n.attached.length);
  toast(t('prune.net.ok', { n: unused.length }));
  render();
}

function machNewSheet() {
  if (!requireSvc()) return;
  const { el } = openSheet(`
    <div class="sheet-h"><h2>${t('mach.new.title')}</h2><button class="icon-btn ghost" data-close>${icon('x')}</button></div>
    <div class="sheet-b">
      <div class="form-group"><label class="form-label">${t('mach.new.image')} *</label>
        <input class="field mono" id="mn-image" list="ml-list" placeholder="alpine:3.22">
        <datalist id="ml-list">${Mock.images.map(i => `<option value="${esc(i.ref)}">`).join('')}</datalist></div>
      <div class="form-group"><label class="form-label">${t('mach.new.name')}</label><input class="field mono" id="mn-name" placeholder="${t('mach.new.name.ph')}"></div>
      <div class="form-row">
        <div class="form-group"><label class="form-label">${t('mach.new.cpus')}</label>
          <span class="stepper"><button type="button" data-step="-1">−</button><output id="mn-cpu">4</output><button type="button" data-step="1">+</button></span></div>
        <div class="form-group"><label class="form-label">${t('mach.new.mem')}</label>
          <select class="field" id="mn-mem"><option value="2147483648">2 GB</option><option value="4294967296">4 GB</option><option value="8589934592" selected>8 GB</option><option value="17179869184">16 GB</option></select></div>
      </div>
      <div class="form-group"><label class="form-label">${t('mach.new.home')}</label>
        <div class="radio-cards" id="mn-home">
          ${[['rw', t('mach.home.rw')], ['ro', t('mach.home.ro')], ['none', t('mach.home.none')]].map(([v, l], i) =>
            `<button type="button" class="radio-card${i === 0 ? ' on' : ''}" data-v="${v}">${l}</button>`).join('')}
        </div></div>
      <label class="check-row" style="margin-bottom:9px"><span class="switch"><input type="checkbox" id="mn-virt"><i></i></span><span>${t('mach.new.virt')}</span></label>
      <label class="check-row"><span class="switch"><input type="checkbox" id="mn-def"><i></i></span><span>${t('mach.new.def')}</span></label>
    </div>
    ${sheetFooter(t('act.cancel'), t('act.create'))}`);
  let home = 'rw';
  el.addEventListener('click', e => {
    const st = e.target.closest('[data-step]');
    if (st) { const o = el.querySelector('#mn-cpu'); o.textContent = clamp(+o.textContent + +st.dataset.step, 1, 16); }
    const rc = e.target.closest('.radio-card');
    if (rc) { home = rc.dataset.v; el.querySelectorAll('.radio-card').forEach(x => x.classList.toggle('on', x === rc)); }
  });
  el.querySelector('#sheet-submit').addEventListener('click', () => {
    const image = el.querySelector('#mn-image').value.trim();
    if (!image) return toast(t('run.err.image'), 'err');
    let name = el.querySelector('#mn-name').value.trim()
      || image.split(':')[0].split('/').pop() + '-machine';
    const setDef = el.querySelector('#mn-def').checked;
    if (setDef) Mock.machines.forEach(m => m.isDefault = false);
    Mock.machines.push({
      name, image, state: 'running',
      cpus: +el.querySelector('#mn-cpu').textContent, mem: +el.querySelector('#mn-mem').value,
      homeMount: home, virtualization: el.querySelector('#mn-virt').checked,
      isDefault: setDef || !Mock.machines.some(m => m.isDefault), created: Date.now()
    });
    close();
    toast(`${name} · ${t('st.running')}`);
    updateBadges();
    if (S.route !== 'machines') go('machines'); else render();
  });
  el.querySelector('#mn-image').focus();
}

function machineShellDrawer(name) {
  const m = Mock.machines.find(x => x.name === name);
  if (!m) return;
  const { el } = openDrawer(`
    <div class="drawer-h">
      <div style="flex:1"><h2>${esc(name)}</h2><div class="sub">container machine run -n ${esc(name)}</div></div>
      <button class="icon-btn ghost" data-close>${icon('x')}</button>
    </div>
    <div class="drawer-b" id="ms-root"></div>`);
  mountTerminal(el.querySelector('#ms-root'), { host: name });
}

function syslogsDrawer() {
  const { el } = openDrawer(`
    <div class="drawer-h">
      <div style="flex:1"><h2>${t('syslog.title')}</h2><div class="sub">container system logs</div></div>
      <button class="icon-btn ghost" data-close>${icon('x')}</button>
    </div>
    <div class="drawer-b">
      <div class="logbar">
        <label class="check-row"><span class="switch"><input type="checkbox" id="sl-follow"${S.syslogFollow ? ' checked' : ''}><i></i></span><span>${t('logs.follow')}</span></label>
        <select class="field" id="sl-range" style="width:auto;height:26px;font-size:12px">
          <option value="5m"${S.syslogRange === '5m' ? ' selected' : ''}>${t('syslog.5m')}</option>
          <option value="1h"${S.syslogRange === '1h' ? ' selected' : ''}>${t('syslog.1h')}</option>
          <option value="1d"${S.syslogRange === '1d' ? ' selected' : ''}>${t('syslog.1d')}</option>
        </select>
      </div>
      <div class="log-view" id="sl-view"></div>
    </div>`);
  const view = el.querySelector('#sl-view');
  const count = { '5m': 14, '1h': 30, '1d': 60 }[S.syslogRange];
  const gen = () => {
    const tpl = Mock.sysLogTemplates[Math.floor(Math.random() * Mock.sysLogTemplates.length)];
    let [comp, rest] = tpl;
    rest = rest.replace('{size}', String(Math.round(rnd(1, 90))) + 'MB')
      .replace('{uptime}', String(Math.round((Date.now() - Mock.system.startedAt) / 1000)));
    const ts = new Date(Date.now() - rnd(0, { '5m': 300e3, '1h': 3600e3, '1d': 86400e3 }[S.syslogRange]))
      .toLocaleTimeString(I18N.locale(), { hour12: false });
    return `<div><span class="t">${ts}</span>[${comp}] ${esc(rest)}</div>`;
  };
  view.innerHTML = Array.from({ length: count }, gen).join('');
  view.scrollTop = view.scrollHeight;
  let tmr = null;
  const wire = () => {
    clearInterval(tmr);
    tmr = setInterval(() => {
      view.insertAdjacentHTML('beforeend', gen());
      while (view.children.length > 400) view.firstChild.remove();
      view.scrollTop = view.scrollHeight;
    }, 1200);
  };
  el.querySelector('#sl-follow').addEventListener('change', e => {
    S.syslogFollow = e.target.checked;
    S.syslogFollow ? wire() : clearInterval(tmr);
  });
  el.querySelector('#sl-range').addEventListener('change', e => {
    S.syslogRange = e.target.value;
    view.innerHTML = Array.from({ length: count }, gen).join('');
    view.scrollTop = view.scrollHeight;
  });
  if (S.syslogFollow) wire();
}

document.addEventListener('click', e => {
  const el = e.target.closest('[data-action]');
  if (!el) return;
  const fn = ACT[el.dataset.action];
  if (fn) fn(el);
});
document.addEventListener('input', e => {
  const s = e.target.closest('[data-search]');
  if (!s) return;
  const fid = s.getAttribute('fid');
  const key = { 's-ct': 'ctSearch', 's-img': 'imgSearch', 's-vol': 'volSearch' }[fid] || 'ctSearch';
  S[key] = s.value.trim();
  rerenderList();
});
document.addEventListener('keydown', e => {
  if (recAction) { handleRec(e); return; }
  if (e.key === 'Escape') {
    if (menuEl) return closeMenu();
    const top = overlayStack[overlayStack.length - 1];
    if (top && top._close) top._close();
    return;
  }
  const typing = /INPUT|TEXTAREA|SELECT/.test(document.activeElement.tagName);
  const combo = KEYS.comboFromEvent(e);
  if (!combo) return;
  const hasMod = /^(Mod|Ctrl|Alt)\+/.test(combo);
  if (typing && !hasMod) return;
  for (const [act, c] of Object.entries(KEYS.map)) {
    if (c && c === combo) {
      if (runShortcut(act)) e.preventDefault();
      return;
    }
  }
  if (!typing && combo === '/') {
    const inp = $('[fid^="s-"]');
    if (inp) { e.preventDefault(); inp.focus(); }
  }
});
const LANGS = [
  { code: 'zh', name: '简体中文' },
  { code: 'en', name: 'English' },
  '-',
  { code: 'ja', name: '日本語', soon: true },
  { code: 'fr', name: 'Français', soon: true },
  { code: 'de', name: 'Deutsch', soon: true }
];
ACT['open-lang-menu'] = el => {
  const cur = I18N.getLang();
  showMenu(LANGS.map(l => l === '-' ? '-' : ({
    icon: l.code === cur ? 'check' : '',
    label: l.soon ? `${l.name} · ${t('lang.soon')}` : l.name,
    disabled: !!l.soon,
    fn: () => switchLang(l.code)
  })), el);
};
function switchLang(code) {
  if (code === I18N.getLang()) return;
  I18N.setLang(code);
  document.documentElement.lang = code === 'zh' ? 'zh-CN' : 'en';
  renderSidebarFoot();
  render();
}

matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
  THEME.apply();
  renderSidebarFoot();
});

THEME.apply();
renderSidebarFoot();
go('overview');
