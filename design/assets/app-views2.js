VIEWS.volumes = {
  title: 'vol.title',
  toolbar() {
    return `${searchHtml(t('search.ph.volumes'), S.volSearch, 's-vol')}
      <button class="btn primary" data-action="open-vol-new">${icon('plus')}${t('vol.new.title')}</button>`;
  },
  render() { return offlineBanner() + `<div class="card tbl-wrap"><div id="list-region">${this.list()}</div></div>`; },
  list() {
    let rows = [...Mock.volumes];
    if (S.volSearch) rows = rows.filter(v => v.name.toLowerCase().includes(S.volSearch.toLowerCase()));
    if (!rows.length) {
      return S.volSearch
        ? emptyHtml('search', t('ct.nomatch'), '', 'clear-search')
        : emptyHtml('db', t('vol.empty'), t('vol.empty.hint'), 'open-vol-new', t('vol.new.title'));
    }
    return `<table class="tbl"><thead><tr>
      <th style="width:24%">${t('vol.name')}</th><th>${t('vol.size')}</th><th>${t('vol.journal')}</th>
      <th>${t('vol.attached')}</th><th>${t('vol.created')}</th><th style="width:64px"></th></tr></thead><tbody>
      ${rows.map(v => `<tr data-action="row-open" data-kind="volume" data-id="${esc(v.name)}" tabindex="0">
        <td><div class="cell-main">${esc(v.name)}</div></td>
        <td class="num">${v.size ? fmtBytes(v.size) : '—'}</td>
        <td>${v.journal ? `<span class="chip">${v.journal}</span>` : '<span style="color:var(--text-3)">—</span>'}</td>
        <td>${v.usedBy.length ? v.usedBy.map(u => `<span class="chip">${esc(u)}</span>`).join(' ') : '<span style="color:var(--text-3)">—</span>'}</td>
        <td class="num">${relTime(v.created)}</td>
        <td><div class="row-actions">
          <button class="mini-act danger" data-action="vol-delete" data-id="${esc(v.name)}">${icon('trash')}</button>
        </div></td></tr>`).join('')}</tbody></table>`;
  }
};

function volumeDrawer(name) {
  const v = Mock.volumes.find(x => x.name === name);
  if (!v) return;
  openDrawer(`
    <div class="drawer-h">
      <div style="flex:1"><h2>${esc(v.name)}</h2><div class="sub">driver: ${esc(v.driver)}</div></div>
      <button class="icon-btn ghost" data-close>${icon('x')}</button>
    </div>
    <div class="drawer-b">
      <dl class="kv mono">
        <dt>${t('vol.size')}</dt><dd>${v.size ? fmtBytes(v.size) : t('ct.d.none')}</dd>
        <dt>${t('vol.journal')}</dt><dd>${v.journal || 'default'}</dd>
        <dt>${t('vol.attached')}</dt><dd>${v.usedBy.join(', ') || t('ct.d.none')}</dd>
        <dt>${t('vol.created')}</dt><dd>${fmtDate(v.created)}</dd>
      </dl>
    </div>`);
}

VIEWS.networks = {
  title: 'net.title',
  toolbar() { return `<button class="btn primary" data-action="open-net-new">${icon('plus')}${t('net.new.title')}</button>`; },
  render() {
    return offlineBanner() + `
      ${S.netNoteDismissed ? '' : `<div class="banner" id="mac26-note">${icon('info')}<div><b>macOS 26</b> · ${t('net.mac26.note')}</div>
        <button class="mini-act x" data-action="dismiss-note" style="opacity:1">${icon('x')}</button></div>`}
      <div id="list-region">${this.list()}</div>`;
  },
  list() {
    const customs = Mock.networks.filter(n => !n.system);
    if (!customs.length) return `<div class="card">${emptyHtml('globe', t('net.empty'), t('net.empty.hint'), 'open-net-new', t('net.new.title'))}</div>`;
    return `<div class="mach-grid">${Mock.networks.map(n => `
      <div class="card mach-card">
        <div class="mach-top"><h4>${icon('globe')} ${esc(n.name)}</h4>
          ${n.system ? `<span class="badge accent">${t('net.default.tag')}</span>` : ''}
          ${n.internal ? `<span class="badge">${icon('shield')} ${t('net.internal')}</span>` : ''}</div>
        <div class="mach-meta mono" style="font-size:12px">
          <span>${t('net.subnet4')}: <b>${esc(n.subnet4)}</b></span>
          ${n.subnet6 ? `<span>${t('net.subnet6')}: <b>${esc(n.subnet6)}</b></span>` : ''}
          <span style="font-family:var(--font);margin-top:2px;color:var(--text-2)">${t('net.attached')}: ${n.attached.length ? n.attached.map(a => esc(a)).join(', ') : t('ct.d.none')}</span>
        </div>
        ${!n.system ? `<div class="mach-foot">
          <span style="flex:1"></span>
          <button class="btn small danger" data-action="net-delete" data-id="${esc(n.name)}">${icon('trash')}${t('act.delete')}</button>
        </div>` : ''}
      </div>`).join('')}</div>`;
  }
};

VIEWS.machines = {
  title: 'mach.title',
  toolbar() { return `<button class="btn primary" data-action="open-mach-new">${icon('plus')}${t('mach.new.title')}</button>`; },
  render() {
    return offlineBanner() + `
      <p style="color:var(--text-2);font-size:12.5px;margin:-4px 0 14px">${t('mach.sub')}</p>
      <div id="list-region">${this.list()}</div>`;
  },
  list() {
    if (!Mock.machines.length) return `<div class="card">${emptyHtml('display', t('mach.empty'), t('mach.empty.hint'), 'open-mach-new', t('mach.new.title'))}</div>`;
    return `<div class="mach-grid">${Mock.machines.map(m => `
      <div class="card mach-card">
        <div class="mach-top">
          <h4>${esc(m.name)}</h4>
          ${m.isDefault ? `<span class="badge star">${icon('star')} ${t('mach.default')}</span>` : ''}
          <span class="status ${m.state === 'running' ? 'running' : 'stopped'}"><span class="dot"></span>${t(m.state === 'running' ? 'mach.running' : 'mach.stopped')}</span>
        </div>
        <div class="mach-meta">
          <span>${t('mach.image')}: <b class="mono" style="font-size:11.5px">${esc(m.image)}</b></span>
          <span>${t('mach.resources')}: <b>${m.cpus} CPU · ${fmtBytes(m.mem)}</b></span>
          <span>${t('mach.home')}: <b>${m.homeMount.toUpperCase()}</b>${m.virtualization ? ` · <b>${t('mach.new.virt').split('（')[0]}</b>` : ''}</span>
          <span>${t('mach.created')}: ${relTime(m.created)}</span>
        </div>
        <div class="mach-foot">
          ${m.isDefault ? '' : `<button class="btn small" data-action="mach-setdef" data-id="${esc(m.name)}">${icon('star')}${t('act.setDefault')}</button>`}
          <span style="flex:1"></span>
          ${m.state === 'running'
            ? `<button class="btn small" data-action="mach-shell" data-id="${esc(m.name)}">${icon('term')}${t('act.shell')}</button>
               <button class="btn small" data-action="mach-stop" data-id="${esc(m.name)}">${icon('stop')}${t('act.stop')}</button>`
            : `<button class="btn small" data-action="mach-start" data-id="${esc(m.name)}">${icon('play')}${t('act.start')}</button>`}
          <button class="mini-act" data-action="row-menu" data-kind="machine" data-id="${esc(m.name)}">${icon('dots')}</button>
        </div>
      </div>`).join('')}</div>`;
  }
};

function machineMenu(m) {
  showMenu([
    { icon: 'sliders', label: t('act.config'), fn: () => SIM.machineConfig(m) },
    { icon: 'log', label: t('act.viewLogs'), fn: () => machineLogsDrawer(m) },
    '-',
    { icon: 'trash', label: t('act.delete'), danger: true, fn: async () => {
        if (!await alertBox({ title: t('del.mach.title', { n: m.name }), msg: esc(t('del.mach.msg')), confirmLabel: t('confirm.yes'), danger: true })) return;
        Mock.machines = Mock.machines.filter(x => x.name !== m.name);
        toast(m.name + ' · ' + t('act.delete'));
        updateBadges(); rerenderList();
      } }
  ], document.querySelector(`[data-kind="machine"][data-id="${CSS.escape(m.name)}"]`));
}

function machineLogsDrawer(m) {
  const { el } = openDrawer(`
    <div class="drawer-h">
      <div style="flex:1"><h2>${esc(m.name)}</h2><div class="sub">container machine logs</div></div>
      <button class="icon-btn ghost" data-close>${icon('x')}</button>
    </div>
    <div class="drawer-b">
      <div class="logbar">
        <label class="check-row"><span class="switch"><input type="checkbox" checked id="ml-follow"><i></i></span><span>${t('logs.follow')}</span></label>
      </div>
      <div class="log-view" id="ml-view">${genLogLines({ image: '__boot__' }, 8)}
        ${Mock.bootLog.slice(0, 6).map(l => `<div><span class="t">boot</span>${esc(l)}</div>`).join('')}
      </div>
    </div>`);
  const view = el.querySelector('#ml-view');
  view.scrollTop = view.scrollHeight;
  let tmr = null;
  el.querySelector('#ml-follow').addEventListener('change', e => {
    if (e.target.checked) tmr = setInterval(() => {
      view.insertAdjacentHTML('beforeend', genLogLine({ image: Object.keys(Mock.logTemplates)[0] }));
      view.scrollTop = view.scrollHeight;
    }, 1100);
    else clearInterval(tmr);
  });
  if (tmr) clearInterval(tmr);
  if (el.querySelector('#ml-follow').checked) tmr = setInterval(() => {
    view.insertAdjacentHTML('beforeend', genLogLine({ image: Object.keys(Mock.logTemplates)[0] }));
    view.scrollTop = view.scrollHeight;
  }, 1100);
}

VIEWS.k8s = {
  title: 'k8.title',
  toolbar() { return `<button class="btn primary" data-action="open-k8-new">${icon('plus')}${t('k8.new.title')}</button>`; },
  render() {
    return offlineBanner() + `
      ${S.k8sNoteDismissed ? '' : `<div class="banner" id="k8-note">${icon('info')}<div><b>k8s</b> · ${t('k8.exp.note')}</div>
        <button class="mini-act x" data-action="dismiss-k8-note" style="opacity:1">${icon('x')}</button></div>`}
      <p style="color:var(--text-2);font-size:12.5px;margin:-4px 0 14px">${t('k8.sub')}</p>
      <div id="list-region">${this.list()}</div>`;
  },
  list() {
    if (!Mock.k8s.length) return `<div class="card">${emptyHtml('k8s', t('k8.empty'), t('k8.empty.hint'), 'open-k8-new', t('k8.new.title'))}</div>`;
    return `<div class="mach-grid">${Mock.k8s.map(k => {
      const loaded = (Mock.k8sLoaded[k.name] || []).length;
      return `<div class="card mach-card">
        <div class="mach-top">
          <h4>${icon('k8s')} ${esc(k.name)}</h4>
          <span class="status ${k.state === 'running' ? 'running' : 'stopped'}"><span class="dot"></span>${t(k.state === 'running' ? 'st.running' : 'mach.stopped')}</span>
        </div>
        <div class="mach-meta">
          <span>${t('k8.nodeImage')}: <b class="mono" style="font-size:11.5px">${esc(k.nodeImage)}</b></span>
          <span>${t('mach.resources')}: <b>${k.cpus} CPU · ${fmtBytes(k.memBytes)}</b></span>
          <span>${t('k8.images')}: <b>${loaded}</b>${loaded ? `<span class="mono" style="font-size:11px;color:var(--text-2)"> · ${esc((Mock.k8sLoaded[k.name] || []).join(', '))}</span>` : ''}</span>
          ${k.autoRemove ? `<span class="badge">${t('run.opt.rm')}</span>` : ''}
          <span>${t('mach.created')}: ${relTime(k.created)}</span>
        </div>
        <div class="mach-foot">
          ${k.state === 'running'
            ? `<button class="btn small" data-action="k8-loadimg" data-id="${esc(k.name)}">${icon('upload')}${t('k8.loadimg.short')}</button>`
            : `<button class="btn small" data-action="k8-start" data-id="${esc(k.name)}">${icon('play')}${t('act.start')}</button>`}
          <span style="flex:1"></span>
          <button class="mini-act" data-action="row-menu" data-kind="k8s" data-id="${esc(k.name)}">${icon('dots')}</button>
        </div>
      </div>`;
    }).join('')}</div>`;
  }
};

function k8sMenu(c) {
  const items = [];
  if (c.state !== 'running') items.push({ icon: 'play', label: t('act.start'), fn: () => ACT['k8-start'](c.name) });
  items.push({ icon: 'upload', label: t('k8.loadimg.short'), disabled: c.state !== 'running', fn: () => k8sLoadImageSheet(c.name) });
  items.push({ icon: 'key', label: t('k8.writecfg'), disabled: c.state !== 'running', fn: async () => {
    if (!await alertBox({ title: t('k8.writecfg'), msg: esc(t('k8.writecfg.msg')), confirmLabel: t('act.confirm') })) return;
    toast(t('k8.writecfg.doneMsg', { n: c.name }));
  } });
  items.push('-');
  items.push({ icon: 'trash', label: t('act.delete'), danger: true, fn: async () => {
    if (!await alertBox({ title: t('del.k8s.title', { n: c.name }), msg: esc(t('del.k8s.msg')), confirmLabel: t('confirm.yes'), danger: true })) return;
    Mock.k8s = Mock.k8s.filter(x => x.name !== c.name);
    delete Mock.k8sLoaded[c.name];
    toast(c.name + ' · ' + t('act.delete'));
    updateBadges(); rerenderList();
  } });
  showMenu(items, document.querySelector(`[data-kind="k8s"][data-id="${CSS.escape(c.name)}"]`));
}

const PROP_ROWS = Object.entries(Mock.props).flatMap(([sec, kv]) =>
  Object.entries(kv).map(([k, v]) => [`${sec}.${k}`, String(v)]));

const KEY_ROWS = [
  ['nav.overview', () => t('nav.overview')],
  ['nav.containers', () => t('nav.containers')],
  ['nav.images', () => t('nav.images')],
  ['nav.volumes', () => t('nav.volumes')],
  ['nav.networks', () => t('nav.networks')],
  ['nav.machines', () => t('nav.machines')],
  ['nav.k8s', () => t('nav.k8s')],
  ['nav.settings', () => t('nav.settings')],
  ['focus.search', () => t('act.search')],
  ['primary.action', () => t('act.primary')]
];

function settingsShortcutsHtml() {
  const row = ([id, lab]) => `
    <div class="set-line"><span class="lab">${lab()}</span>
      <span class="val"></span>
      <span class="ctl"><button class="keycap" data-action="rec-start" data-rec="${id}">
        <span class="kc-label">${KEYS.map[id] ? KEYS.pretty(KEYS.map[id]) : t('keys.none')}</span>
      </button></span>
    </div>`;
  return `
    <div class="card set-group">
      <div class="grp-head"><h3>${t('keys.title')}</h3><div class="desc">${t('keys.desc')}</div></div>
      ${KEY_ROWS.map(row).join('')}
      <div class="set-line"><span class="lab">${t('act.close')}</span>
        <span class="val"></span>
        <span class="ctl"><span class="keycap fixed">Esc</span></span>
      </div>
      <div class="set-line">
        <span class="ctl" style="flex:1;justify-content:flex-end;padding-top:10px">
          <button class="btn small" data-action="keys-reset">${icon('refresh')}${t('keys.reset')}</button>
        </span>
      </div>
    </div>`;
}

VIEWS.settings = {
  title: 'set.title',
  toolbar() { return ''; },
  render() {
    const sys = Mock.system;
    const appearanceHtml = `
      <div class="card set-group">
        <div class="grp-head"><h3>${t('set.appearance')}</h3></div>
        <div class="set-line"><span class="lab">${t('set.theme')}</span>
          <span class="val"></span>
          <span class="ctl">${segHtml([
            { id: 'auto', label: t('theme.auto') },
            { id: 'light', label: t('theme.light') },
            { id: 'dark', label: t('theme.dark') }
          ], THEME.mode, 'set-theme')}</span>
        </div>
        <div class="set-line"><span class="lab">${t('set.language')}</span>
          <span class="val"></span>
          <span class="ctl"><button class="btn small" data-action="open-lang-menu">
            ${(LANGS.find(l => l.code === I18N.getLang()) || {}).name || 'English'} ${icon('chev-d')}</button></span>
        </div>
      </div>`;
    return `<div class="set-sections">
      ${appearanceHtml}
      <div class="card set-group">
        <div class="grp-head"><h3>${t('set.svc')}</h3><div class="desc">${t('set.svc.desc')} · ${t('set.svc.autostartHint')}</div></div>
        <div class="set-line">
          <span class="lab">${t('set.svc.state')}</span>
          <span class="val"><span class="pill ${sys.servicesRunning ? 'ok' : 'off'}"><span class="dot ${sys.servicesRunning ? 'ok pulse' : 'off'}" style="width:7px;height:7px"></span>${t(sys.servicesRunning ? 'svc.running' : 'svc.stopped')}</span></span>
          <span class="ctl">
            ${sys.servicesRunning
              ? `<button class="btn small" data-action="svc-stop">${icon('power')}${t('svc.stopBtn')}</button>`
              : `<button class="btn small primary" data-action="svc-start">${icon('play')}${t('svc.startBtn')}</button>`}
            <button class="btn small" data-action="open-syslogs">${icon('log')}${t('set.syslogs')}</button>
          </span>
        </div>
        <div class="set-line"><span class="lab">${t('ov.service.version.cli')}</span><span class="val mono">container ${sys.versionCli} (${sys.buildType}/${sys.commitCli})</span></div>
        <div class="set-line"><span class="lab">${t('ov.service.version.api')}</span><span class="val mono">${esc(sys.versionApi)}</span></div>
      </div>

      <div class="card set-group">
        <div class="grp-head"><h3>${t('set.kernel')}</h3><div class="desc">${t('set.kernel.rec')}</div></div>
        <div class="set-line"><span class="lab">${t('set.kernel.current')}</span><span class="val mono">${esc(sys.kernel.path.split('/').pop())}</span></div>
        <div class="set-line"><span class="lab">${t('set.kernel.arch')}</span><span class="val">${sys.kernel.arch}</span></div>
        <div class="set-line"><span class="lab">${t('set.kernel.digest')}</span><span class="val mono">${esc(sys.kernel.digest)}</span></div>
        <div class="set-line">
          <span class="ctl" style="flex:1;justify-content:flex-end;padding-top:10px">
            <button class="btn small primary" data-action="kernel-rec">${icon('download')}${t('act.installRecKernel')}</button>
            <button class="btn small" data-action="kernel-custom">${icon('folder')}${t('act.customKernel')}</button>
          </span>
        </div>
      </div>

      <div class="card set-group">
        <div class="grp-head"><h3>${t('set.dns')}</h3><div class="desc">${t('set.dns.desc')}</div></div>
        ${Mock.dnsDomains.map(d => `
          <div class="set-line"><span class="lab mono">*.${esc(d)}</span>
            <span class="val">/etc/resolver/${esc(d)}</span>
            <span class="ctl"><button class="btn small danger" data-action="dns-del" data-id="${esc(d)}">${icon('trash')}${t('act.remove')}</button></span>
          </div>`).join('')}
        <div class="set-line"><span class="ctl" style="flex:1;gap:8px;padding-top:10px">
          <input class="field" id="dns-input" style="max-width:220px" placeholder="${t('set.dns.add.ph')}">
          <button class="btn small" data-action="dns-add">${icon('plus')}${t('act.add')}</button>
        </span></div>
      </div>

      <div class="card set-group">
        <div class="grp-head"><h3>${t('set.reg')}</h3><div class="desc">${t('set.reg.desc')}</div></div>
        ${Mock.registries.map(r => `
          <div class="set-line"><span class="lab mono">${esc(r.server)}</span>
            <span class="val">${esc(r.user)}</span>
            <span class="ctl"><span class="badge">${r.scheme}</span>
              <button class="btn small" data-action="reg-logout" data-id="${esc(r.server)}">${t('act.logout')}</button></span>
          </div>`).join('')}
        <div class="set-line"><span class="ctl" style="flex:1;justify-content:flex-end;padding-top:10px">
          <button class="btn small primary" data-action="reg-login">${icon('key')}${t('act.login')}</button>
        </span></div>
      </div>

      <div class="card set-group">
        <div class="grp-head"><h3>${t('set.props')}</h3><div class="desc">${t('set.props.desc')}</div></div>
        ${PROP_ROWS.map(([k, v]) => `<div class="set-line"><span class="lab mono">${esc(k)}</span><span class="val mono">${esc(v)}</span></div>`).join('')}
      </div>

      </div>
    ` + settingsShortcutsHtml() + `
      <div class="footer-note">${t('proto.note')}</div>
    </div>`;
  }
};
