const segHtml = (opts, cur, action) => {
  const i = opts.findIndex(o => o.id === cur);
  return `<div class="segmented" style="--seg-i:${i};--seg-n:${opts.length}">` +
    opts.map(o => `<button class="${o.id === cur ? 'on' : ''}" data-action="${action}" data-val="${o.id}">${esc(o.label)}</button>`).join('') + '</div>';
};
const searchHtml = (ph, val, fid) =>
  `<label class="search">${icon('search')}<input type="text" placeholder="${esc(ph)}" value="${esc(val)}" data-search fid="${fid}"></label>`;
const emptyHtml = (iconName, title, hint, btnAction, btnLabel) => `
  <div class="empty"><div class="art">${icon(iconName)}</div><h4>${esc(title)}</h4><p>${esc(hint)}</p>
  ${btnAction ? `<button class="btn primary" data-action="${btnAction}">${icon('plus')}${esc(btnLabel)}</button>` : ''}</div>`;

const offlineBanner = () => Mock.system.servicesRunning ? '' : `
  <div class="banner offline">${icon('warn')}<div><b>${t('svc.notRunning.banner.title')}</b> · ${t('svc.notRunning.banner.msg')}</div></div>`;

VIEWS.overview = {
  title: 'ov.title',
  render() {
    const running = Mock.containers.filter(c => c.status === 'running').length;
    const sys = Mock.system;
    const dfRow = (key, label, d, totalKey) => {
      const activeSize = d.activeSize ?? (d.size - (d.reclaimable || 0));
      const rec = d.reclaimable || 0;
      const tot = d.size;
      return `<div class="df-row"><span class="df-label">${t(label)}</span>
        <div class="df-bar"><i class="used" style="width:${tot ? ((activeSize / tot) * 100).toFixed(1) : 0}%"></i><i class="reclaim" style="width:${tot ? ((rec / tot) * 100).toFixed(1) : 0}%"></i></div>
        <span class="df-meta"><b>${fmtBytes(activeSize)}</b> ${t('ov.disk.reclaimable')} ${fmtBytes(rec)} · ${fmtBytes(tot)}</span></div>`;
    };
    return `
    <div class="grid-ov">
      <button class="card tile" data-action="nav" data-route="containers">
        <span class="k">${icon('box')}${t('ov.tiles.containers')}</span>
        <div class="v">${running}<small>/ ${Mock.containers.length}</small></div></button>
      <button class="card tile" data-action="nav" data-route="images">
        <span class="k">${icon('layers')}${t('ov.tiles.images')}</span><div class="v">${Mock.images.length}</div></button>
      <button class="card tile" data-action="nav" data-route="volumes">
        <span class="k">${icon('db')}${t('ov.tiles.volumes')}</span><div class="v">${Mock.volumes.length}</div></button>
      <button class="card tile" data-action="nav" data-route="networks">
        <span class="k">${icon('globe')}${t('ov.tiles.networks')}</span><div class="v">${Mock.networks.filter(n => !n.system).length}</div></button>
    </div>
    <div class="ov-cols">
      <div class="card">
        <div class="card-h"><h3>${t('ov.disk')}</h3><span class="sub">${t('ov.disk.sub')}</span><span class="spacer"></span>
          <button class="btn small" data-action="maintain-menu" id="maintain-btn">${icon('refresh')}${t('act.maintain')}</button></div>
        <div class="card-b" id="df-body">
          ${dfRow('images', 'ov.disk.images', Mock.df.images)}
          ${dfRow('containers', 'ov.disk.containers', Mock.df.containers)}
          ${dfRow('volumes', 'ov.disk.volumes', Mock.df.volumes)}
          ${dfRow('cache', 'ov.disk.cache', { size: Mock.df.cache.size, reclaimable: Mock.df.cache.reclaimable })}
        </div>
      </div>
      <div class="card">
        <div class="card-h"><h3>${t('ov.service')}</h3><span class="spacer"></span>
          <span class="pill ${sys.servicesRunning ? 'ok' : 'off'}"><span class="dot ${sys.servicesRunning ? 'ok pulse' : 'off'}" style="width:7px;height:7px"></span>${t(sys.servicesRunning ? 'st.running' : 'st.exited')}</span></div>
        <div class="card-b"><dl class="kv mono">
          <dt>${t('ov.service.version.cli')}</dt><dd>container ${sys.versionCli} (${sys.buildType}/${sys.commitCli})</dd>
          <dt>${t('ov.service.version.api')}</dt><dd>${esc(sys.versionApi)}</dd>
          <dt>${t('ov.service.kernel')}</dt><dd>${esc(sys.kernel.path.split('/').pop())}</dd>
          <dt>${t('ov.service.registry')}</dt><dd>${esc(sys.defaultRegistry)}</dd>
          <dt>${t('ov.service.dns')}</dt><dd>.${esc(Mock.dnsDomains[0] || '—')}</dd>
          <dt>${t('ov.service.uptime')}</dt><dd id="uptime-cell">${fmtDur(Date.now() - sys.startedAt)}</dd>
        </dl></div>
      </div>
    </div>`;
  },
  after() {}
};

VIEWS.containers = {
  title: 'ct.title',
  toolbar() {
    return `${segHtml([
      { id: 'all', label: t('filter.all') }, { id: 'running', label: t('filter.running') }, { id: 'stopped', label: t('filter.stopped') }
    ], S.ctFilter, 'ct-filter')}
      ${searchHtml(t('search.ph.containers'), S.ctSearch, 's-ct')}
      <button class="btn primary" data-action="open-run">${icon('plus')}${t('act.runContainer')}</button>`;
  },
  render() { return offlineBanner() + `<div class="card tbl-wrap"><div id="list-region">${this.list()}</div></div>`; },
  list() {
    let rows = [...Mock.containers];
    if (S.ctFilter === 'running') rows = rows.filter(c => c.status === 'running');
    if (S.ctFilter === 'stopped') rows = rows.filter(c => c.status !== 'running');
    if (S.ctSearch) {
      const q = S.ctSearch.toLowerCase();
      rows = rows.filter(c => c.id.toLowerCase().includes(q) || c.image.toLowerCase().includes(q));
    }
    if (!rows.length) {
      return S.ctSearch
        ? emptyHtml('search', t('ct.nomatch'), '', 'clear-search')
        : emptyHtml('box', t('ct.empty'), t('ct.empty.hint'), 'open-run', t('act.runContainer'));
    }
    return `<table class="tbl"><thead><tr>
      <th style="width:22%">${t('ct.name')}</th><th>${t('ct.status')}</th><th>${t('ct.cpu')}</th><th>${t('ct.mem')}</th>
      <th>${t('ct.ip')} / ${t('ct.ports')}</th><th>${t('ct.created')}</th><th style="width:96px"></th></tr></thead><tbody>
      ${rows.map(c => this.row(c)).join('')}</tbody></table>`;
  },
  row(c) {
    initStats(c);
    const running = c.status === 'running';
    const ports = (c.ports || []).map(p => `${p.host}→${p.ct}/${p.proto}`).join(', ') || '';
    return `<tr data-state="${c.status}" data-id="${c.id}" data-action="row-open" data-kind="container" tabindex="0">
      <td><div class="cell-main"><span class="ct-dot"></span>${esc(c.id)}</div><div class="cell-sub mono">${esc(c.image)}</div></td>
      <td><span class="status ${c.status}"><span class="dot"></span>${t(c.status === 'running' ? 'st.running' : c.status === 'exited' ? 'st.exited' : 'st.created')}</span>
        ${!running && c.exitCode ? `<div class="cell-sub">exit ${c.exitCode}</div>` : ''}</td>
      <td class="num" data-live-cpu="${c.id}">${running ? c.cpuPct.toFixed(1) + '%' : '—'}</td>
      <td class="num" data-live-mem="${c.id}">${running ? fmtBytes(c.memBytes) : '—'}</td>
      <td class="mono">${esc(c.ip)}${ports ? `<div class="cell-sub">${esc(ports)}</div>` : ''}</td>
      <td class="num">${relTime(running ? c.startedAt : (c.finishedAt || c.created))}</td>
      <td><div class="row-actions">
        ${running
          ? `<button class="mini-act" data-action="ct-stop" data-id="${c.id}" title="${t('act.stop')}">${icon('stop')}</button>`
          : `<button class="mini-act" data-action="ct-start" data-id="${c.id}" title="${t('act.start')}">${icon('play')}</button>`}
        <button class="mini-act" data-action="row-menu" data-kind="container" data-id="${c.id}" title="">${icon('dots')}</button>
      </div></td></tr>`;
  },
  after() {},
  afterList() {}
};

function containerMenu(c) {
  const items = [];
  if (c.status === 'running') {
    items.push({ icon: 'stop', label: t('act.stop'), fn: () => ACT['ct-stop'](c.id) });
    items.push({ icon: 'zap', label: t('act.kill'), danger: true, fn: () => ACT['ct-kill'](c.id) });
    items.push('-');
  } else {
    items.push({ icon: 'play', label: t('act.start'), fn: () => ACT['ct-start'](c.id) });
  }
  items.push({ icon: 'export', label: t('act.exportFs'), fn: () => SIM.exportFs(c.id) });
  items.push({ icon: 'copy', label: t('act.copyId'), fn: () => copyText(c.id) });
  items.push('-');
  items.push({
    icon: 'trash', label: t('act.delete'), danger: true,
    fn: async () => {
      if (!await alertBox({ title: t('del.ct.title', { id: c.id }), msg: esc(t('del.ct.msg')), confirmLabel: t('confirm.yes'), danger: true })) return;
      Mock.containers = Mock.containers.filter(x => x.id !== c.id);
      toast(t('act.delete') + ' · ' + c.id);
      updateBadges(); rerenderList();
      Mock.df.containers.count--; Mock.df.containers.reclaimable += 50e6;
    }
  });
  showMenu(items, document.querySelector(`[data-kind="container"][data-id="${c.id}"] .mini-act:last-child`));
}

function containerDrawer(id) {
  const c = Mock.containers.find(x => x.id === id);
  if (!c) return;
  S.drawerId = id;
  stopLogFollow();
  stopStatsLoop();
  initStats(c);
  S.drawerTab = S.drawerTab || 'info';
  const { wrap, el, close } = openDrawer(`
    <div class="drawer-h">
      <div style="flex:1;min-width:0">
        <h2>${esc(c.id)}</h2>
        <div class="sub">${esc(c.image)} · ${esc(c.ip)}</div>
      </div>
      <button class="icon-btn ghost" data-close>${icon('x')}</button>
    </div>
    <div class="tabs" id="ct-tabs">
      <button data-tab="info" class="${S.drawerTab === 'info' ? 'on' : ''}">${t('ct.tab.info')}</button>
      <button data-tab="logs" class="${S.drawerTab === 'logs' ? 'on' : ''}">${t('ct.tab.logs')}</button>
      <button data-tab="stats" class="${S.drawerTab === 'stats' ? 'on' : ''}">${t('ct.tab.stats')}</button>
      <button data-tab="term" class="${S.drawerTab === 'term' ? 'on' : ''}">${t('ct.tab.term')}</button>
    </div>
    <div class="drawer-b" id="ct-drawer-b"></div>`);
  wrap._ctx = { kind: 'container', id };
  drawCtTab();
  el.querySelector('#ct-tabs').addEventListener('click', e => {
    const b = e.target.closest('[data-tab]');
    if (!b) return;
    S.drawerTab = b.dataset.tab;
    el.querySelectorAll('#ct-tabs button').forEach(x => x.classList.toggle('on', x.dataset.tab === S.drawerTab));
    drawCtTab();
  });

  function drawCtTab() {
    const body = el.querySelector('#ct-drawer-b');
    stopLogFollow();
    if (S.drawerTab === 'info') body.innerHTML = ctInfoHtml(c);
    else if (S.drawerTab === 'logs') { body.innerHTML = ctLogsHtml(); startLogFollow(body); }
    else if (S.drawerTab === 'stats') { body.innerHTML = ctStatsHtml(c); startStatsLoop(el, c); }
    else { body.innerHTML = ''; mountTerminal(body, { host: c.id }); }
  }
  wrap._redraw = drawCtTab;
}

function ctInfoHtml(c) {
  const optRows = [
    [t('run.opt.init'), c.init], ['Rosetta', c.rosetta],
    [t('run.opt.ro'), c.readOnly], [t('run.opt.rm'), c.autoRemove]
  ].filter(x => x[1]);
  return `
    <div class="logbar" style="padding-top:0">
      ${c.status === 'running'
        ? `<button class="btn small" data-action="ct-stop" data-id="${c.id}">${icon('stop')}${t('act.stop')}</button>
           <button class="btn small danger" data-action="ct-kill" data-id="${c.id}">${icon('zap')}${t('act.kill')}</button>`
        : `<button class="btn small" data-action="ct-start" data-id="${c.id}">${icon('play')}${t('act.start')}</button>`}
      <button class="btn small" data-action="copy" data-copy="${esc(c.ip)}">${icon('copy')}${t('ct.ip')}</button>
      <button class="btn small" data-action="sim-export" data-id="${c.id}">${icon('export')}${t('act.exportFs')}</button>
    </div>
    <dl class="kv mono">
      <dt>${t('ct.d.id')}</dt><dd>${esc(c.id)}</dd>
      <dt>${t('ct.image')}</dt><dd>${esc(c.image)}</dd>
      <dt>${t('ct.status')}</dt><dd>${t(c.status === 'running' ? 'st.running' : c.status === 'exited' ? 'st.exited' : 'st.created')}${c.exitCode != null ? ` (${c.exitCode})` : ''}</dd>
      <dt>${t('ct.d.arch')}</dt><dd>linux/arm64</dd>
      <dt>${t('ct.d.cmd')}</dt><dd>${esc(c.entrypoint ? c.entrypoint + ' ' : '')}${esc(c.cmd || '')}</dd>
      <dt>${t('run.net')}</dt><dd>${esc(c.network)}</dd>
      <dt>${t('ct.ports')}</dt><dd>${(c.ports || []).map(p => esc(`${p.host}:${p.ct}/${p.proto}`)).join('<br>') || t('ct.d.none')}</dd>
      <dt>${t('run.res')}</dt><dd>${c.cpus} CPU · ${fmtBytes(c.memLimit)}</dd>
      <dt>${t('ct.created')}</dt><dd>${fmtDate(c.created)}</dd>
    </dl>
    <details class="disclosure" open><summary>${icon('chev-r')}${t('ct.d.env')}</summary>
      <div class="disc-body"><dl class="kv mono">
        ${Object.entries(c.env || {}).map(([k, v]) => `<dt>${esc(k)}</dt><dd>${esc(v)}</dd>`).join('') || `<dt></dt><dd style="color:var(--text-3)">${t('ct.d.none')}</dd>`}
      </dl></div></details>
    <details class="disclosure"><summary>${icon('chev-r')}${t('ct.d.mounts')}</summary>
      <div class="disc-body"><dl class="kv mono">
        ${(c.mounts || []).map(m => `<dt>${esc(m.src)}</dt><dd>→ ${esc(m.dst)}</dd>`).join('') || `<dt></dt><dd style="color:var(--text-3)">${t('ct.d.none')}</dd>`}
      </dl></div></details>
    ${optRows.length ? `<details class="disclosure"><summary>${icon('chev-r')}${t('ct.d.options')}</summary>
      <div class="disc-body">${optRows.map(([k]) => `<span class="badge accent">${esc(k)}</span>`).join(' ')}</div></details>` : ''}`;
}

let logTimer = null, logFollowOn = true, logBoot = false, logTail = 0;
function stopLogFollow() { if (logTimer) { clearInterval(logTimer); logTimer = null; } }
function genLogLine(c) {
  const tpl = (Mock.logTemplates[c.image] || ['…']).length
    ? Mock.logTemplates[c.image] : ['level=info msg=heartbeat'];
  let line = tpl[Math.floor(Math.random() * tpl.length)];
  line = line.replace('[date]', new Date().toISOString());
  const ts = new Date().toLocaleTimeString(I18N.locale(), { hour12: false });
  return `<div><span class="t">${ts}</span>${esc(line)}</div>`;
}
function ctLogsHtml() {
  const c = Mock.containers.find(x => x.id === S.drawerId);
  const lines = logBoot ? Mock.bootLog : Array.from({ length: 14 }, () => '');
  const body = logBoot
    ? Mock.bootLog.map(l => `<div><span class="t">boot</span>${esc(l)}</div>`).join('')
    : genLogLines(c, 14);
  return `
    <div class="logbar">
      <label class="check-row"><span class="switch"><input type="checkbox" id="lg-follow" ${logFollowOn ? 'checked' : ''}><i></i></span><span>${t('logs.follow')}</span></label>
      <label class="check-row"><span class="switch"><input type="checkbox" id="lg-boot" ${logBoot ? 'checked' : ''}><i></i></span><span>${t('logs.boot')}</span></label>
      <select class="field" id="lg-tail" style="width:auto;height:26px;font-size:12px">
        <option value="0"${logTail === 0 ? ' selected' : ''}>${t('logs.all')}</option>
        <option value="100"${logTail === 100 ? ' selected' : ''}>100</option>
        <option value="500"${logTail === 500 ? ' selected' : ''}>500</option>
      </select>
    </div>
    <div class="log-view" id="lg-view">${body}</div>`;
}
function genLogLines(c, n) {
  let out = '';
  for (let i = 0; i < n; i++) out += genLogLine(c);
  return out;
}
function startLogFollow(body) {
  const view = body.querySelector('#lg-view');
  const c = Mock.containers.find(x => x.id === S.drawerId);
  body.querySelector('#lg-follow').addEventListener('change', e => {
    logFollowOn = e.target.checked;
    stopLogFollow();
    if (logFollowOn && !logBoot && c && c.status === 'running') logTimer = setInterval(() => appendLog(view), 900);
  });
  body.querySelector('#lg-boot').addEventListener('change', e => {
    logBoot = e.target.checked;
    view.innerHTML = logBoot
      ? Mock.bootLog.map(l => `<div><span class="t">boot</span>${esc(l)}</div>`).join('')
      : genLogLines(c, 14);
    view.scrollTop = view.scrollHeight;
    stopLogFollow();
    if (logFollowOn && !logBoot && c && c.status === 'running') logTimer = setInterval(() => appendLog(view), 900);
  });
  body.querySelector('#lg-tail').addEventListener('change', e => { logTail = +e.target.value; });
  if (logFollowOn && !logBoot && c && c.status === 'running') logTimer = setInterval(() => appendLog(view), 900);
  view.scrollTop = view.scrollHeight;
}
function appendLog(view) {
  const c = Mock.containers.find(x => x.id === S.drawerId);
  if (!view.isConnected || !c) return stopLogFollow();
  view.insertAdjacentHTML('beforeend', genLogLine(c));
  while (view.children.length > 300) view.firstChild.remove();
  view.scrollTop = view.scrollHeight;
}

let statsLoop = null;
function stopStatsLoop() { if (statsLoop) { cancelAnimationFrame(statsLoop); clearInterval(statsLoop.i); statsLoop = null; } }
function ctStatsHtml(c) {
  return `
    <div class="chart-box"><h5>${t('stats.cpu')} <output id="o-cpu">${c.cpuPct.toFixed(1)}%</output></h5><canvas id="cv-cpu"></canvas></div>
    <div class="chart-box"><h5>${t('stats.mem')} <output id="o-mem">${fmtBytes(c.memBytes)} / ${fmtBytes(c.memLimit)}</output></h5><canvas id="cv-mem"></canvas></div>
    <div class="chart-box"><h5>${t('stats.net')} <output id="o-net">${fmtBytes(c.rxRate)}/s ↓ · ${fmtBytes(c.txRate)}/s ↑</output></h5><canvas id="cv-net"></canvas></div>
    <dl class="kv">
      <dt>${t('stats.pids')}</dt><dd>${Math.round(clamp(c.cpuPct * 3 + 4, 4, 64))}</dd>
      <dt>${t('stats.block')} ${t('stats.read').toLowerCase()}</dt><dd>${fmtBytes(c.rxRate * 37)}</dd>
      <dt>${t('stats.block')} ${t('stats.write').toLowerCase()}</dt><dd>${fmtBytes(c.txRate * 52)}</dd>
    </dl>`;
}
function startStatsLoop(drawerEl, c) {
  stopStatsLoop();
  const tick = () => {
    if (!document.body.contains(drawerEl)) return stopStatsLoop();
    if (S.drawerTab !== 'stats') return;
    const cc = Mock.containers.find(x => x.id === c.id);
    const cvC = $('#cv-cpu'); if (!cvC) return;
    drawSeries(cvC, cc.hist.cpu, getComputedStyle(document.documentElement).getPropertyValue('--accent').trim());
    drawSeries($('#cv-mem'), cc.hist.mem, '#af52de');
    drawSeries($('#cv-net'), cc.hist.rx, '#30b0c7');
    $('#o-cpu').textContent = cc.cpuPct.toFixed(1) + '%';
    $('#o-mem').textContent = fmtBytes(cc.memBytes) + ' / ' + fmtBytes(cc.memLimit);
    $('#o-net').textContent = fmtBytes(cc.rxRate) + '/s ↓ · ' + fmtBytes(cc.txRate) + '/s ↑';
  };
  tick();
  statsLoop = setInterval(tick, 1000);
}

function mountTerminal(root, { host }) {
  root.innerHTML = `
    <div class="term"><div class="term-scroll" id="tm-scroll">
      <div class="term-line dim">container exec -it ${esc(host)} /bin/sh</div>
      <div class="term-line dim">${t('term.help')}</div>
    </div>
    <div class="term-input"><span class="term-prompt" id="tm-prompt">${esc(host)}:/#</span>
    <input id="tm-in" autocomplete="off" spellcheck="false" placeholder="${t('term.ph')}"></div></div>`;
  const scroll = root.querySelector('#tm-scroll');
  const input = root.querySelector('#tm-in');
  const prompt = root.querySelector('#tm-prompt');
  const print = (txt, cls = '') => {
    const div = document.createElement('div');
    div.className = 'term-line ' + cls;
    div.textContent = txt;
    scroll.appendChild(div);
    scroll.scrollTop = scroll.scrollHeight;
  };
  setTimeout(() => input.focus(), 60);
  input.addEventListener('keydown', e => {
    if (e.key === 'Enter') {
      const raw = input.value.trim();
      print(prompt.textContent + ' ' + raw);
      input.value = '';
      if (!raw) return;
      const [cmd, ...args] = raw.split(/\s+/);
      const a = args.join(' ');
      switch (cmd) {
        case 'help':
          print('ls  ps  pwd  whoami  uname -a  cat <file>  echo <text>  df  free  clear  exit', 'dim'); break;
        case 'clear': scroll.innerHTML = ''; break;
        case 'pwd': print('/'); break;
        case 'whoami': print('root'); break;
        case 'uname': print(a.includes('-a')
          ? `Linux ${host} 6.18.35 #1 SMP PREEMPT arm64 GNU/Linux`
          : 'Linux'); break;
        case 'ls': print('bin   dev   etc   home   proc   root   tmp   usr   var'); break;
        case 'ps': print('PID   USER     TIME   COMMAND\n    1 root     0:00   ' + (host === 'dev-machine' ? '/sbin/init' : './app')); break;
        case 'cat':
          if (a.includes('os-release')) print('NAME="Alpine Linux"\nID=alpine\nVERSION_ID=3.22.0');
          else if (a.includes('hostname')) print(host);
          else if (a.includes('cpuinfo')) print('processor\t: 0\nModel\t\t: Apple M-series Virtual CPU');
          else print(`cat: can't open '${a || '?'}': No such file or directory`, 'err');
          break;
        case 'echo': print(a.replace(/^["']|["']$/g, '')); break;
        case 'df': print('Filesystem           Size      Used Available Use% Mounted on\noverlay              9.8G      1.2G      8.6G  12% /'); break;
        case 'free': print('            total       used       free\nMem:        1010564     213120     797444'); break;
        case 'exit': print('exit', 'dim'); break;
        default: print(`sh: ${cmd}: not found`, 'err');
      }
    }
  });
}

function imageDrawer(ref) {
  const img = Mock.images.find(x => x.ref === ref);
  if (!img) return;
  const { wrap, el } = openDrawer(`
    <div class="drawer-h">
      <div style="flex:1;min-width:0">
        <h2>${esc(img.ref)}</h2>
        <div class="sub">${esc(img.digest)}</div>
      </div>
      <button class="icon-btn ghost" data-close>${icon('x')}</button>
    </div>
    <div class="drawer-b">
      <div class="logbar" style="padding-top:0">
        <button class="btn small" data-action="img-run" data-ref="${esc(img.ref)}">${icon('play')}${t('act.runContainer')}</button>
        <button class="btn small" data-action="img-push" data-ref="${esc(img.ref)}">${icon('upload')}${t('act.push')}</button>
        <button class="btn small" data-action="img-tag" data-ref="${esc(img.ref)}">${icon('tag')}${t('act.tagNew')}</button>
        <button class="btn small" data-action="img-save" data-ref="${esc(img.ref)}">${icon('download')}${t('act.saveTar')}</button>
      </div>
      <dl class="kv mono">
        <dt>ID</dt><dd>${esc(img.id)}</dd>
        <dt>${t('img.size')}</dt><dd>${fmtBytes(img.size)}</dd>
        <dt>${t('img.osarch')}</dt><dd>${img.os}/${img.arch}</dd>
        <dt>${t('img.usedBy')}</dt><dd>${img.usedBy.length ? img.usedBy.map(esc).join(', ') : t('ct.d.none')}</dd>
        <dt>${t('img.created')}</dt><dd>${fmtDate(img.created)}</dd>
      </dl>
      <details class="disclosure" open><summary>${icon('chev-r')}${t('pull.layer')}s · ${img.layers.length}</summary>
        <div class="disc-body"><div class="layers">
          ${img.layers.map(l => `<div class="layer"><span class="cmd">${esc(l.cmd)}</span><span class="sz">${l.size > 4096 ? fmtBytes(l.size) : ''}</span></div>`).join('')}
        </div></div></details>
    </div>`);
}

VIEWS.images = {
  title: 'img.title',
  toolbar() {
    return `${searchHtml(t('search.ph.images'), S.imgSearch, 's-img')}
      <button class="btn" data-action="open-build">${icon('hammer')}${t('act.build')}</button>
      <button class="btn primary" data-action="open-pull">${icon('download')}${t('act.pull')}</button>`;
  },
  render() { return offlineBanner() + `<div class="card tbl-wrap"><div id="list-region">${this.list()}</div></div>`; },
  list() {
    let rows = [...Mock.images];
    if (S.imgSearch) {
      const q = S.imgSearch.toLowerCase();
      rows = rows.filter(i => i.ref.toLowerCase().includes(q));
    }
    if (!rows.length) {
      return S.imgSearch
        ? emptyHtml('search', t('img.nomatch'), '', 'clear-search')
        : emptyHtml('layers', t('img.empty'), t('img.empty.hint'), 'open-pull', t('act.pull'));
    }
    return `<table class="tbl"><thead><tr>
      <th style="width:30%">${t('img.ref')}</th><th>${t('img.size')}</th><th>${t('img.osarch')}</th>
      <th>${t('img.usedBy')}</th><th>${t('img.created')}</th><th style="width:96px"></th></tr></thead><tbody>
      ${rows.map(i => `<tr data-action="row-open" data-kind="image" data-id="${esc(i.ref)}" tabindex="0">
        <td><div class="cell-main">${esc(i.ref)}</div><div class="cell-sub mono">${esc(i.id)}</div></td>
        <td class="num">${fmtBytes(i.size)}</td>
        <td class="mono">${i.os}/${i.arch}</td>
        <td>${i.usedBy.length ? `<span class="badge green">${i.usedBy.length}</span>` : '<span class="badge gray">—</span>'}</td>
        <td class="num">${relTime(i.created)}</td>
        <td><div class="row-actions">
          <button class="mini-act" data-action="img-run" data-ref="${esc(i.ref)}" title="${t('act.runContainer')}">${icon('play')}</button>
          <button class="mini-act" data-action="row-menu" data-kind="image" data-id="${esc(i.ref)}">${icon('dots')}</button>
        </div></td></tr>`).join('')}</tbody></table>`;
  }
};

function imageMenu(img) {
  showMenu([
    { icon: 'upload', label: t('act.push'), fn: () => SIM.push(img.ref) },
    { icon: 'tag', label: t('act.tagNew'), fn: () => SIM.tagDialog(img.ref) },
    '-',
    { icon: 'download', label: t('act.saveTar'), fn: () => SIM.saveTar(img.ref) },
    { icon: 'trash', label: t('act.delete'), danger: true, fn: async () => {
        if (img.usedBy.length) { toast(t('del.img.inuse'), 'err'); return; }
        if (!await alertBox({ title: t('del.img.title', { ref: img.ref }), msg: esc(t('del.img.msg')), confirmLabel: t('confirm.yes'), danger: true })) return;
        Mock.images = Mock.images.filter(x => x.ref !== img.ref);
        Mock.df.images.count--;
        toast(img.ref + ' · ' + t('act.delete'));
        updateBadges(); render();
      } }
  ], document.querySelector(`[data-kind="image"][data-id="${CSS.escape(img.ref)}"] .mini-act:last-child`) || $('.page-actions button:last-child'));
}

function copyText(txt) {
  navigator.clipboard && navigator.clipboard.writeText(txt).catch(() => {});
  toast(t('copied'));
}
