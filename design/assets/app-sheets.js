function kvRowHtml(ph1, ph2, v1 = '', v2 = '', single = false) {
  return `<div class="kv-row${single ? ' single' : ''}">
    <input class="field" placeholder="${esc(ph1)}" value="${esc(v1)}">
    <input class="field" placeholder="${esc(ph2)}" value="${esc(v2)}">
    <button class="kv-del" data-kv-del>${icon('x')}</button></div>`;
}
function kvCollect(container) {
  return [...container.querySelectorAll('.kv-row')].map(r => {
    const [a, b] = r.querySelectorAll('input');
    return [a.value.trim(), b.value.trim()];
  }).filter(([a, b]) => a || b);
}
const sheetFooter = (cancelLabel, submitLabel, submitIcon = 'check', submitAction = '') => `
  <div class="sheet-f"><button class="btn" data-close>${esc(cancelLabel)}</button>
  <button class="btn primary" ${submitAction ? `data-action="${submitAction}"` : ''} id="sheet-submit">${submitIcon ? icon(submitIcon) : ''}${esc(submitLabel)}</button></div>`;

function requireSvc() {
  if (Mock.system.servicesRunning) return true;
  toast(t('svc.notRunning.banner.title'), 'err');
  return false;
}

function runSheet(prefillImage = '') {
  if (!requireSvc()) return;
  const netOpts = ['default', ...Mock.networks.filter(n => !n.system).map(n => n.name)];
  const { el, close } = openSheet(`
    <div class="sheet-h"><h2>${t('run.title')}</h2><button class="icon-btn ghost" data-close>${icon('x')}</button></div>
    <div class="sheet-b">
      <div class="form-group"><label class="form-label">${t('run.image')} *</label>
        <input class="field mono" id="rs-image" list="img-list" placeholder="${t('run.image.ph')}" value="${esc(prefillImage)}">
        <datalist id="img-list">${Mock.images.map(i => `<option value="${esc(i.ref)}">`).join('')}</datalist>
        <div class="form-err" id="rs-err">${t('run.err.image')}</div></div>
      <div class="form-row">
        <div class="form-group"><label class="form-label">${t('run.name')}</label><input class="field" id="rs-name" placeholder="${t('run.name.ph')}"></div>
        <div class="form-group"><label class="form-label">${t('run.workdir')}</label><input class="field mono" id="rs-workdir" placeholder="/app"></div>
      </div>
      <div class="form-group"><label class="form-label">${t('run.cmd')}</label><input class="field mono" id="rs-cmd" placeholder="${t('run.cmd.ph')}"></div>
      <div class="form-row-3">
        <div class="form-group"><label class="form-label">${t('run.cpus')}</label>
          <span class="stepper"><button type="button" data-step="-1">−</button><output id="rs-cpu-out">2</output><button type="button" data-step="1">+</button></span></div>
        <div class="form-group"><label class="form-label">${t('run.memory')}</label>
          <select class="field" id="rs-mem"><option value="536870912">512 MB</option><option value="1073741824" selected>1 GB</option><option value="2147483648">2 GB</option><option value="4294967296">4 GB</option><option value="8589934592">8 GB</option></select></div>
        <div class="form-group"><label class="form-label">${t('run.net')}</label>
          <select class="field" id="rs-net">${netOpts.map(n => `<option>${esc(n)}</option>`).join('')}</select></div>
      </div>
      <div class="form-group"><label class="form-label">${t('run.ports')}</label>
        <div class="kv-editor" id="kv-ports">${kvRowHtml(t('run.port.ph.host'), t('run.port.ph.ct'))}</div>
        <button class="add-link" data-kv-add="kv-ports" data-p1="${t('run.port.ph.host')}" data-p2="${t('run.port.ph.ct')}">${icon('plus')}${t('act.add')}</button></div>
      <div class="form-group"><label class="form-label">${t('run.vols')}</label>
        <div class="kv-editor" id="kv-vols"></div>
        <button class="add-link" data-kv-add="kv-vols" data-p1="${t('run.vol.ph.host')}" data-p2="${t('run.vol.ph.ct')}">${icon('plus')}${t('act.add')}</button></div>
      <div class="form-group"><label class="form-label">${t('run.env')}</label>
        <div class="kv-editor" id="kv-env"></div>
        <button class="add-link" data-kv-add="kv-env" data-p1="${t('run.env.k')}" data-p2="${t('run.env.v')}">${icon('plus')}${t('act.add')}</button></div>
      <details class="disclosure"><summary>${icon('chev-r')}${t('run.adv')}</summary>
        <div class="disc-body">
          <label class="check-row"><span class="switch"><input type="checkbox" id="sw-init"><i></i></span><span>${t('run.opt.init')}</span></label>
          <label class="check-row"><span class="switch"><input type="checkbox" id="sw-rosetta"><i></i></span><span>${t('run.opt.rosetta')}</span></label>
          <label class="check-row"><span class="switch"><input type="checkbox" id="sw-ro"><i></i></span><span>${t('run.opt.ro')}</span></label>
          <label class="check-row"><span class="switch"><input type="checkbox" id="sw-rm"><i></i></span><span>${t('run.opt.rm')}</span></label>
          <label class="check-row"><span class="switch"><input type="checkbox" id="sw-tty"><i></i></span><span>${t('run.opt.tty')}</span></label>
        </div></details>
    </div>
    ${sheetFooter(t('act.cancel'), t('run.submit'), 'play')}`);
  el.addEventListener('click', e => {
    const st = e.target.closest('[data-step]');
    if (st) {
      const out = el.querySelector('#rs-cpu-out');
      out.textContent = clamp((+out.textContent || 0) + (+st.dataset.step), 1, 16);
    }
    const add = e.target.closest('[data-kv-add]');
    if (add) {
      const box = el.querySelector('#' + add.dataset.kvAdd);
      box.insertAdjacentHTML('beforeend', kvRowHtml(add.dataset.p1, add.dataset.p2));
      box.lastElementChild.querySelector('input').focus();
    }
    const del = e.target.closest('[data-kv-del]');
    if (del) del.closest('.kv-row').remove();
  });
  const submit = () => {
    const image = el.querySelector('#rs-image').value.trim();
    if (!image) { el.querySelector('#rs-err').classList.add('show'); return; }
    let name = el.querySelector('#rs-name').value.trim();
    if (!name) name = image.split('/')[0].split(':')[0].replace(/[^a-z0-9_-]/gi, '-') + '-' + Math.random().toString(36).slice(2, 5);
    if (Mock.containers.some(c => c.id === name)) { toast(t('run.name') + ': ' + name + ' ✕', 'err'); return; }
    const memBytes = +el.querySelector('#rs-mem').value;
    const c = {
      id: name, image, status: 'running', cpus: +el.querySelector('#rs-cpu-out').textContent,
      memLimit: memBytes, cpuPct: rnd(0.3, 3), memBytes: memBytes * rnd(0.06, 0.14),
      rxRate: rnd(500, 9000), txRate: rnd(500, 9000),
      ip: `192.168.64.${6 + Mock.containers.length % 200}`, network: el.querySelector('#rs-net').value,
      ports: kvCollect(el.querySelector('#kv-ports')).map(([h, p]) => ({ host: h.split(':')[0] || h, ct: p.split('/')[0], proto: (p.split('/')[1] || 'tcp') })),
      created: Date.now(), startedAt: Date.now(),
      cmd: el.querySelector('#rs-cmd').value.trim() || '/bin/sh', entrypoint: '',
      workdir: el.querySelector('#rs-workdir').value.trim() || '/',
      user: 'root',
      env: Object.fromEntries(kvCollect(el.querySelector('#kv-env')).filter(([k]) => k)),
      mounts: kvCollect(el.querySelector('#kv-vols')).map(([s, d]) => ({ src: s, dst: d })),
      init: el.querySelector('#sw-init').checked, rosetta: el.querySelector('#sw-rosetta').checked,
      readOnly: el.querySelector('#sw-ro').checked, autoRemove: el.querySelector('#sw-rm').checked,
      tty: el.querySelector('#sw-tty').checked
    };
    Mock.containers.unshift(c);
    Mock.df.containers.count++;
    close();
    toast(`${c.id} · ${t('st.running')}`);
    updateBadges();
    if (S.route === 'containers' || S.route === 'overview') render(); else go('containers');
    requestAnimationFrame(() => {
      const tr = document.querySelector(`tr[data-id="${CSS.escape(c.id)}"]`);
      tr && tr.classList.add('flash');
    });
  };
  el.querySelector('#sheet-submit').addEventListener('click', submit);
  el.querySelector('#rs-image').focus();
}

function pullSheet() {
  if (!requireSvc()) return;
  const { el, close } = openSheet(`
    <div class="sheet-h"><h2>${t('pull.title')}</h2><button class="icon-btn ghost" data-close>${icon('x')}</button></div>
    <div class="sheet-b" id="pf-body">
      <div class="form-group"><label class="form-label">${t('pull.ref')} *</label>
        <input class="field mono" id="pf-ref" placeholder="${t('pull.ref.ph')}">
        <div class="form-err" id="pf-err">${t('run.err.image')}</div></div>
      <div class="form-group"><label class="form-label">${t('pull.platform')}</label>
        <select class="field" id="pf-platform"><option value="">${t('pull.platform.auto')}</option><option>linux/arm64</option><option>linux/amd64</option></select></div>
    </div>
    ${sheetFooter(t('act.cancel'), t('pull.begin'), 'download')}`);
  const start = () => {
    const refInput = el.querySelector('#pf-ref');
    const ref = refInput.value.trim();
    if (!ref) { el.querySelector('#pf-err').classList.add('show'); return; }
    const body = el.querySelector('#pf-body');
    const layers = Array.from({ length: 4 + Math.floor(Math.random() * 3) }, () => Math.round(rnd(0.4, 90)));
    body.innerHTML = `
      <dl class="kv mono" style="margin-bottom:10px"><dt>${t('pull.ref')}</dt><dd>${esc(ref)}</dd>
      <dt>${t('pull.platform')}</dt><dd>${el.querySelector('#pf-platform').value || 'linux/arm64'}</dd></dl>
      <div class="pull-layers">${layers.map((mb, i) => `
        <div class="pl-row"><span class="mono dim" style="color:var(--text-2)">#${(i + 1).toString().padStart(2, '0')}</span>
          <div class="progress"><i data-pl></i></div>
          <span class="st" data-st>${fmtBytes(mb * 1048576)}</span></div>`).join('')}</div>`;
    const footerBtn = el.querySelector('#sheet-submit');
    footerBtn.disabled = true;
    let done = 0;
    layers.forEach((mb, i) => setTimeout(() => {
      const bar = body.querySelectorAll('[data-pl]')[i];
      const st = body.querySelectorAll('[data-st]')[i];
      if (!bar) return;
      st.textContent = t('pull.downloading');
      bar.style.width = '30%';
      setTimeout(() => { bar.style.width = '78%'; }, 350);
      setTimeout(() => { bar.style.width = '100%'; st.textContent = t('pull.verifying'); }, 800);
      setTimeout(() => {
        done++;
        if (done === layers.length) {
          st.textContent = t('pull.done');
          const size = layers.reduce((a, b) => a + b, 0) * 1048576;
          const fullRef = ref.includes(':') ? ref : ref + ':latest';
          Mock.images.unshift({
            ref: fullRef, id: Math.random().toString(16).slice(2, 14), size,
            os: 'linux', arch: 'arm64', created: Date.now(), digest: 'sha256:' + Math.random().toString(16).slice(2, 8) + '…' + Math.random().toString(16).slice(2, 6),
            usedBy: [], layers: layers.map(mb => ({ cmd: 'ADD layer in / ', size: mb * 1048576 }))
          });
          Mock.df.images.count++;
          toast(t('pull.doneMsg', { ref: fullRef, size: fmtBytes(size) }));
          footerBtn.disabled = false;
          footerBtn.innerHTML = `${icon('check')}${t('act.done')}`;
          footerBtn.onclick = close;
          updateBadges();
          if (S.route === 'images' || S.route === 'overview') render();
        }
      }, 1150);
    }, i * 420));
  };
  el.querySelector('#sheet-submit').addEventListener('click', start);
  el.querySelector('#pf-ref').focus();
}

const BUILD_STEPS = [
  ['FROM node:20-alpine', true],
  ['WORKDIR /app', false],
  ['COPY package*.json ./', false],
  ['RUN npm ci --omit=dev', false],
  ['COPY . .', false],
  ['LABEL com.apple.container.image=true', false],
  ['CMD ["node", "server.js"]', false]
];

function buildSheet() {
  if (!requireSvc()) return;
  const { el, close } = openSheet(`
    <div class="sheet-h"><h2>${t('build.title')}</h2><button class="icon-btn ghost" data-close>${icon('x')}</button></div>
    <div class="sheet-b">
      <div class="form-row">
        <div class="form-group"><label class="form-label">${t('build.dockerfile')}</label><input class="field mono" id="bf-file" value="Dockerfile"></div>
        <div class="form-group"><label class="form-label">${t('build.context')}</label><input class="field mono" id="bf-ctx" value="."></div>
      </div>
      <div class="form-group"><label class="form-label">${t('build.tags')} *</label>
        <div class="tags-input" id="bf-tags"><input id="bf-tag-in" placeholder="${t('build.tag.ph')}"></div>
        <div class="form-err" id="bf-err">${t('run.err.image')}</div></div>
      <div class="form-group"><label class="form-label">${t('build.args')}</label>
        <div class="kv-editor" id="kv-bargs"></div>
        <button class="add-link" data-kv-add="kv-bargs" data-p1="NODE_VERSION" data-p2="18">${icon('plus')}${t('act.add')}</button></div>
      <div class="form-row">
        <div class="form-group"><label class="form-label">${t('build.target')}</label><input class="field mono" id="bf-target" placeholder="${t('build.target.ph')}"></div>
        <div class="form-group" style="display:flex;align-items:flex-end;gap:16px;padding-bottom:2px">
          <label class="check-row"><span class="switch"><input type="checkbox" id="bf-nocache"><i></i></span><span style="font-size:12px">${t('build.opt.nocache')}</span></label>
          <label class="check-row"><span class="switch"><input type="checkbox" id="bf-pull"><i></i></span><span style="font-size:12px">${t('build.opt.pull')}</span></label>
        </div>
      </div>
    </div>
    ${sheetFooter(t('act.cancel'), t('build.submit'), 'hammer')}`);
  const tagsBox = el.querySelector('#bf-tags');
  const tagIn = el.querySelector('#bf-tag-in');
  const getTags = () => [...tagsBox.querySelectorAll('.tag-chip')].map(c => c.dataset.v);
  const addTag = v => {
    v = v.trim().replace(/,$/, '');
    if (!v || getTags().includes(v)) return;
    tagIn.insertAdjacentHTML('beforebegin',
      `<span class="tag-chip" data-v="${esc(v)}">${esc(v)}<button type="button">${icon('x')}</button></span>`);
  };
  tagIn.addEventListener('keydown', e => {
    if ((e.key === 'Enter' || e.key === ',') && tagIn.value.trim()) { e.preventDefault(); addTag(tagIn.value); tagIn.value = ''; }
    else if (e.key === 'Backspace' && !tagIn.value) {
      const chips = tagsBox.querySelectorAll('.tag-chip');
      chips.length && chips[chips.length - 1].remove();
    }
  });
  tagsBox.addEventListener('click', e => {
    const rm = e.target.closest('.tag-chip button');
    if (rm) rm.closest('.tag-chip').remove();
    else tagsBox.querySelector('input').focus();
  });
  el.addEventListener('click', e => {
    const add = e.target.closest('[data-kv-add]');
    if (add) {
      const box = el.querySelector('#' + add.dataset.kvAdd);
      box.insertAdjacentHTML('beforeend', kvRowHtml(add.dataset.p1, add.dataset.p2));
      box.lastElementChild.querySelector('input').focus();
    }
    const del = e.target.closest('[data-kv-del]');
    if (del) del.closest('.kv-row').remove();
  });
  el.querySelector('#sheet-submit').addEventListener('click', () => {
    if (!getTags().length) { el.querySelector('#bf-err').classList.add('show'); return; }
    const nocache = el.querySelector('#bf-nocache').checked;
    const firstTag = getTags()[0];
    const b = el.querySelector('.sheet-b');
    b.innerHTML = `<dl class="kv mono" style="margin-bottom:10px">
        <dt>Dockerfile</dt><dd>${esc(el.querySelector('#bf-file').value)}</dd>
        <dt>${t('build.context')}</dt><dd>${esc(el.querySelector('#bf-ctx').value)}</dd></dl>
      <div class="progress" style="margin-bottom:10px"><i id="bf-prog"></i></div>
      <div class="build-log" id="bf-log"></div>`;
    const log = b.querySelector('#bf-log');
    const prog = b.querySelector('#bf-prog');
    const btn = el.querySelector('#sheet-submit');
    btn.disabled = true;
    const line = html => { log.insertAdjacentHTML('beforeend', html); log.scrollTop = log.scrollHeight; };
    line(`<span class="dim">$ container build -t ${esc(firstTag)} .</span>`);
    BUILD_STEPS.forEach(([cmd], i) => setTimeout(() => {
      const cached = !nocache && i === 0 && !el._pulled;
      line(`<span class="stepno">[${i + 1}/${BUILD_STEPS.length}]</span> RUN ${esc(cmd.replace(/^FROM |^RUN |^COPY /, m => m))} <span class="${cached ? 'dim' : 'ok'}">${cached ? '[cached]' : '✓ ' + (rnd(0.4, 6)).toFixed(1) + 's'}</span>`);
      prog.style.width = (((i + 1) / (BUILD_STEPS.length + 1)) * 100).toFixed(0) + '%';
    }, 380 * i + 300));
    setTimeout(() => {
      const size = Math.round(rnd(120, 260)) * 1048576;
      prog.style.width = '100%';
      line(`<span class="ok">DONE · exporting layers → oci://</span>`);
      Mock.images.unshift({
        ref: firstTag, id: Math.random().toString(16).slice(2, 14), size,
        os: 'linux', arch: 'arm64', created: Date.now(),
        digest: 'sha256:' + Math.random().toString(16).slice(2, 8) + '…' + Math.random().toString(16).slice(2, 6),
        usedBy: [],
        layers: BUILD_STEPS.map(([c]) => ({ cmd: c, size: Math.round(rnd(1024, 40e6)) }))
      });
      Mock.df.images.count++;
      toast(t('build.doneMsg', { ref: firstTag, size: fmtBytes(size) }));
      btn.disabled = false;
      btn.innerHTML = `${icon('check')}${t('act.done')}`;
      btn.onclick = close;
      updateBadges();
      if (S.route === 'images' || S.route === 'overview') render();
    }, 380 * BUILD_STEPS.length + 700);
  });
  tagIn.focus();
}

function k8sCreateSheet() {
  if (!requireSvc()) return;
  const { el } = openSheet(`
    <div class="sheet-h"><h2>${t('k8.new.title')}</h2><button class="icon-btn ghost" data-close>${icon('x')}</button></div>
    <div class="sheet-b">
      <div class="form-group"><label class="form-label">${t('k8.new.name')} *</label>
        <input class="field mono" id="kn-name" placeholder="${t('mach.new.name.ph')}" value="k8s-dev"></div>
      <div class="form-group"><label class="form-label">${t('k8.new.image')}</label>
        <input class="field mono" id="kn-image" placeholder="${t('k8.new.image.ph')}" value="docker.io/kindest/node:v1.35.5"></div>
      <div class="form-row">
        <div class="form-group"><label class="form-label">${t('mach.new.cpus')}</label>
          <span class="stepper"><button type="button" data-step="-1">−</button><output id="kn-cpu">4</output><button type="button" data-step="1">+</button></span></div>
        <div class="form-group"><label class="form-label">${t('mach.new.mem')}</label>
          <select class="field" id="kn-mem"><option value="2147483648">2 GB</option><option value="4294967296">4 GB</option><option value="8589934592" selected>8 GB</option><option value="17179869184">16 GB</option></select></div>
      </div>
      <label class="check-row"><span class="switch"><input type="checkbox" id="kn-rm"><i></i></span><span>${t('k8.new.rm')}</span></label>
      <p class="hint">${t('k8.exp.note')}</p>
    </div>
    ${sheetFooter(t('act.cancel'), t('act.create'))}`);
  el.addEventListener('click', e => {
    const st = e.target.closest('[data-step]');
    if (st) { const o = el.querySelector('#kn-cpu'); o.textContent = clamp(+o.textContent + +st.dataset.step, 2, 16); }
  });
  el.querySelector('#sheet-submit').addEventListener('click', () => {
    const name = el.querySelector('#kn-name').value.trim();
    if (!name) return toast(t('run.err.image'), 'err');
    if (Mock.k8s.some(k => k.name === name)) return toast(t('set.dns.exists'), 'err');
    Mock.k8s.push({
      name, nodeImage: el.querySelector('#kn-image').value.trim() || 'docker.io/kindest/node:v1.35.5',
      state: 'running', cpus: +el.querySelector('#kn-cpu').textContent,
      memBytes: +el.querySelector('#kn-mem').value,
      autoRemove: el.querySelector('#kn-rm').checked, created: Date.now()
    });
    Mock.k8sLoaded[name] = [];
    close();
    toast(t('k8.create.ok', { n: name }));
    updateBadges();
    if (S.route !== 'k8s') go('k8s'); else render();
  });
  el.querySelector('#kn-name').focus();
}

function k8sLoadImageSheet(clusterName) {
  if (!requireSvc()) return;
  const { el } = openSheet(`
    <div class="sheet-h"><h2>${t('k8.loadimg.title', { n: clusterName })}</h2><button class="icon-btn ghost" data-close>${icon('x')}</button></div>
    <div class="sheet-b">
      <div class="form-group"><label class="form-label">${t('k8.loadimg.ref')} *</label>
        <input class="field mono" id="kl-ref" list="kl-list" placeholder="${t('k8.loadimg.ph')}">
        <datalist id="kl-list">${Mock.images.map(i => `<option value="${esc(i.ref)}">`).join('')}</datalist>
        <div class="form-err" id="kl-err">${t('run.err.image')}</div></div>
      <div class="progress" style="display:none" id="kl-wrap"><i id="kl-bar"></i></div>
    </div>
    ${sheetFooter(t('act.cancel'), t('k8.loadimg.short'), 'upload')}`);
  const submit = () => {
    const ref = el.querySelector('#kl-ref').value.trim();
    if (!ref) { el.querySelector('#kl-err').classList.add('show'); return; }
    const wrap = el.querySelector('#kl-wrap');
    wrap.style.display = 'block';
    const bar = el.querySelector('#kl-bar');
    const btn = el.querySelector('#sheet-submit');
    btn.disabled = true;
    let p = 0;
    const tmr = setInterval(() => {
      p = Math.min(100, p + rnd(9, 24));
      bar.style.width = p + '%';
      if (p >= 100) {
        clearInterval(tmr);
        Mock.k8sLoaded[clusterName] = [...(Mock.k8sLoaded[clusterName] || []), ref];
        setTimeout(() => {
          close();
          toast(t('k8.loadimg.doneMsg', { img: ref, n: clusterName }));
          rerenderList();
        }, 300);
      }
    }, 160);
  };
  el.querySelector('#sheet-submit').addEventListener('click', submit);
  el.querySelector('#kl-ref').focus();
}

async function ctLifecycle(id, op) {
  const c = Mock.containers.find(x => x.id === id);
  if (!c || c._busy) return;
  if (op === 'stop') {
    c.status = 'stopped'; c.finishedAt = Date.now(); c.cpuPct = 0; c.memBytes = 0;
    toast(`${id} · ${t('act.stop')}`);
  } else if (op === 'start') {
    if (!requireSvc()) return;
    c.status = 'running'; c.startedAt = Date.now();
    initStats(c);
    toast(`${id} · ${t('act.start')}`);
  } else if (op === 'kill') {
    if (!await alertBox({ title: t('kill.title', { id }), msg: esc(t('kill.msg')), confirmLabel: t('confirm.kill'), danger: true })) return;
    c.status = 'exited'; c.exitCode = 137; c.finishedAt = Date.now();
    toast(`${id} · SIGKILL`, 'ok');
  }
  c.hist = null;
  initStats(c);
  updateBadges();
  render();
  const dr = $('#ct-drawer-b');
  if (dr && S.drawerId === id && VIEWS.containers) {}
}

const SIM = {
  exportFs(id) {
    if (!requireSvc()) return;
    const { el, close } = openSheet(`
      <div class="sheet-h"><h2>${t('exporting.title', { id })}</h2></div>
      <div class="sheet-b"><p style="color:var(--text-2);margin-bottom:10px;font-size:12.5px">${t('exporting.msg')}</p>
      <div class="progress"><i id="xp-bar"></i></div></div>`);
    const bar = el.querySelector('#xp-bar');
    let p = 0;
    const tmr = setInterval(() => {
      p = Math.min(100, p + rnd(8, 22));
      bar.style.width = p + '%';
      if (p >= 100) {
        clearInterval(tmr);
        setTimeout(() => { close(); toast(t('export.doneMsg', { path: '~/Downloads/' + id + '.tar' })); }, 350);
      }
    }, 180);
  },
  push(ref) {
    if (!requireSvc()) return;
    const { el, close } = openSheet(`
      <div class="sheet-h"><h2>${t('push.title', { ref })}</h2></div>
      <div class="sheet-b"><div class="progress"><i id="pp-bar"></i></div></div>`);
    const bar = el.querySelector('#pp-bar');
    let p = 0;
    const tmr = setInterval(() => {
      p = Math.min(100, p + rnd(6, 18));
      bar.style.width = p + '%';
      if (p >= 100) { clearInterval(tmr); setTimeout(() => { close(); toast(t('push.doneMsg', { ref })); }, 320); }
    }, 170);
  },
  tagDialog(sourceRef) {
    const { el } = openSheet(`
      <div class="sheet-h"><h2>${t('tagd.title')}</h2><button class="icon-btn ghost" data-close>${icon('x')}</button></div>
      <div class="sheet-b">
        <div class="form-group"><label class="form-label">${t('tagd.source')}</label><input class="field mono" value="${esc(sourceRef)}" disabled style="opacity:.75"></div>
        <div class="form-group"><label class="form-label">${t('tagd.target')}</label><input class="field mono" id="tg-in" placeholder="${t('tagd.target.ph')}"></div>
      </div>
      ${sheetFooter(t('act.cancel'), t('act.confirm'))}`);
    const apply = () => {
      const target = el.querySelector('#tg-in').value.trim();
      if (!target) return;
      close();
      toast(`${target} ← ${sourceRef}`);
      if (S.route === 'images') render();
    };
    el.querySelector('#sheet-submit').onclick = apply;
  },
  saveTar(ref) {
    const defPath = '~/Downloads/' + ref.split('/').pop().replace(':', '_') + '.tar';
    const { el } = openSheet(`
      <div class="sheet-h"><h2>${t('saved.title')}</h2><button class="icon-btn ghost" data-close>${icon('x')}</button></div>
      <div class="sheet-b">
        <div class="form-group"><label class="form-label">${t('saved.output')}</label><input class="field mono" id="sv-path" value="${defPath}"></div>
        <div class="progress" style="display:none" id="sv-wrap"><i id="sv-bar"></i></div>
      </div>
      ${sheetFooter(t('act.cancel'), t('act.save'), 'download')}`);
    el.querySelector('#sheet-submit').addEventListener('click', () => {
      const path = el.querySelector('#sv-path').value.trim() || defPath;
      const wrapEl = el.querySelector('#sv-wrap');
      wrapEl.style.display = 'block';
      const bar = el.querySelector('#sv-bar');
      const btn = el.querySelector('#sheet-submit');
      btn.disabled = true;
      let p = 0;
      const tmr = setInterval(() => {
        p = Math.min(100, p + rnd(10, 25));
        bar.style.width = p + '%';
        if (p >= 100) {
          clearInterval(tmr);
          setTimeout(() => { close(); toast(t('saved.doneMsg', { path })); }, 300);
        }
      }, 150);
    });
  },
  machineConfig(m) {
    const { el } = openSheet(`
      <div class="sheet-h"><h2>${t('mach.cfg.title', { n: m.name })}</h2><button class="icon-btn ghost" data-close>${icon('x')}</button></div>
      <div class="sheet-b">
        <p class="hint" style="margin:-2px 0 12px">${t('mach.cfg.note')}</p>
        <div class="form-row">
          <div class="form-group"><label class="form-label">${t('mach.new.cpus')}</label>
            <span class="stepper"><button type="button" data-step="-1">−</button><output id="mc-cpu">${m.cpus}</output><button type="button" data-step="1">+</button></span></div>
          <div class="form-group"><label class="form-label">${t('mach.new.mem')}</label>
            <select class="field" id="mc-mem">${[2, 4, 8, 16, 32].filter(g => g * GB !== m.mem).concat([m.mem / GB]).sort((a, b) => a - b)
              .map(g => `<option value="${g * GB}"${g * GB === m.mem ? ' selected' : ''}>${g} GB</option>`).join('')}</select></div>
        </div>
        <div class="form-group"><label class="form-label">${t('mach.new.home')}</label>
          <div class="radio-cards" id="mc-home">
            ${[['rw', t('mach.home.rw')], ['ro', t('mach.home.ro')], ['none', t('mach.home.none')]].map(([v, l]) =>
              `<button type="button" class="radio-card${m.homeMount === v ? ' on' : ''}" data-v="${v}">${l}</button>`).join('')}
          </div></div>
        <div class="form-group"><label class="form-label">${t('mach.cfg.kernel')}</label>
          <input class="field mono" id="mc-kernel" placeholder="${t('mach.cfg.kernel.ph')}" value=""></div>
        <label class="check-row"><span class="switch"><input type="checkbox" id="mc-virt"${m.virtualization ? ' checked' : ''}><i></i></span><span>${t('mach.new.virt')}</span></label>
      </div>
      ${sheetFooter(t('act.cancel'), t('act.save'))}`);
    let home = m.homeMount;
    el.addEventListener('click', e => {
      const st = e.target.closest('[data-step]');
      if (st) { const o = el.querySelector('#mc-cpu'); o.textContent = clamp(+o.textContent + +st.dataset.step, 1, 16); }
      const rc = e.target.closest('.radio-card');
      if (rc) { home = rc.dataset.v; el.querySelectorAll('.radio-card').forEach(x => x.classList.toggle('on', x === rc)); }
    });
    el.querySelector('#sheet-submit').addEventListener('click', () => {
      m.cpus = +el.querySelector('#mc-cpu').textContent;
      m.mem = +el.querySelector('#mc-mem').value;
      m.homeMount = home;
      m.virtualization = el.querySelector('#mc-virt').checked;
      close();
      toast(m.name + ' · ' + t('act.save'));
      render();
    });
  }
};
