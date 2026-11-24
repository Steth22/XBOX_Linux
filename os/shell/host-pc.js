// UraxOS PC Mode glue. The same design page runs as two layer-shell surfaces:
//   "desk": wallpaper + desktop icons, below every app window
//   "bar":  taskbar, Start, flyouts, dialogs, above app windows (only the visible parts take clicks)
// Real app windows are KWin windows; the taskbar lists them through urax.windows().
(function () {
  if (!window.urax || window.urax.mode() !== 'desktop') return;
  const U = window.urax, SURF = U.surface();

  // ---- look: only PC Mode, no console layers, no boot screen ----
  const css = document.createElement('style');
  css.textContent =
    '#boot,#pcxf,#pcur,#pcalt,#kb,#fw,#rest{display:none!important}' +
    '#stage>*:not(#pc):not(#toast):not(#dg):not(#nwrap){display:none!important}' +
    (SURF === 'bar'
      ? 'html,body,#fit,#stage,#pc{background:transparent!important}#pcwall,#pcicons,#pcwins,#pcsnap{display:none!important}'
      : '#pctb,#pcstart,#pcfly,#pctv,#pclock,#pcnight{display:none!important}');
  document.head.appendChild(css);
  if (window.FSD && FSD.Desktop) FSD.Desktop.ch = [];
  pcOpen();
  const xf = document.getElementById('pcxf');
  if (xf) xf.className = '';

  // ---- real apps behind the design's app keys ----
  const REAL = {
    files: { exec: 'dolphin', app: 'org.kde.dolphin' },
    brave: { exec: 'firefox', app: 'firefox', n: 'Firefox' },
    steam: { exec: 'steam', app: 'steam' },
    term: { exec: 'konsole', app: 'org.kde.konsole' },
    settings: { exec: 'systemsettings', app: 'systemsettings' },
    taskmgr: { exec: 'plasma-systemmonitor', app: 'org.kde.plasma-systemmonitor' },
    notes: { exec: 'kwrite', app: 'org.kde.kwrite' },
    photos: { exec: 'gwenview', app: 'org.kde.gwenview' }
  };
  const missing = ['discord', 'store', 'calc'];
  Object.keys(REAL).forEach(k => {
    const r = REAL[k];
    if (r.n) { PAPPS[k].n = r.n; PAPPS[k].img = null; }
    PAPPS[k].open = () => openApp(k);
  });
  missing.forEach(k => { PAPPS[k].open = () => toast(PAPPS[k].n + ' is not installed yet'); });
  PIN = PIN.filter(k => !missing.includes(k));
  PSTART.splice(0, PSTART.length, ...PSTART.filter(k => !missing.includes(k)));
  PAPPS.console.open = () => U.consoleMode();

  // Built-in design windows become the real apps.
  pcExplorer = () => openApp('files');
  pcBrowser = () => openApp('brave');
  pcSteam = () => openApp('steam');
  pcTerm = () => openApp('term');
  pcSettings = () => openApp('settings');
  pcTaskMgr = () => openApp('taskmgr');
  pcNotes = () => openApp('notes');
  pcPhotos = () => openApp('photos');
  pcDiscord = () => PAPPS.discord.open();
  pcStore = () => PAPPS.store.open();
  pcCalc = () => PAPPS.calc.open();
  pcClose = fast => { pcStartT(false); pcFlyT(null); if (!fast) U.consoleMode(); };
  pcTaskView = () => U.spawn('busctl --user call org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component invokeShortcut s Overview');
  let deskShown = false;
  pcShowDesk = () => { deskShown = !deskShown; U.showDesktop(deskShown); };

  function openApp(k) {
    pcStartT(false);
    const ws = WINS.filter(w => keyOf(w) === k);
    if (ws.length) { U.winActivate(ws[0].id); return; }
    U.spawn(REAL[k].exec);
    toast('Opening ' + PAPPS[k].n + '…');
  }

  // Extra installed apps (flatpak, desktop files) appear in Start too.
  U.apps(list => {
    (list || []).filter(x => x.src !== 'steam').forEach(x => {
      const cmd = x.exec.split(' ')[0];
      if (Object.values(REAL).some(r => r.exec === cmd)) return;
      const k = 'x:' + x.n;
      PAPPS[k] = { n: x.n, c: ['#2A3A55', '#121B2E'], i: 'app', open: () => { pcStartT(false); U.spawn(x.exec); } };
      if (!PSTART.includes(k)) PSTART.push(k);
    });
  });

  // ---- real windows on the taskbar ----
  let WINS = [];
  const keyOf = w => {
    for (const k in REAL) if (REAL[k].app === w.app || REAL[k].exec === w.app) return k;
    const k = 'w:' + w.app;
    if (!PAPPS[k]) PAPPS[k] = { n: w.title || w.app, c: ['#2A3A55', '#121B2E'], i: 'app', img: () => w.icon, open: () => U.winActivate(w.id) };
    return k;
  };
  function refresh() { U.windows(list => { WINS = Array.isArray(list) ? list : []; if (SURF === 'bar') pcTaskbar(); }); }
  U.onWindows(() => { clearTimeout(refresh.t); refresh.t = setTimeout(refresh, 80); });

  pcTbApp = function (a) {
    const ws = WINS.filter(w => keyOf(w) === a);
    if (!ws.length) { PAPPS[a].open(); return; }
    if (ws.length === 1) { U.winToggle(ws[0].id); return; }
    const i = ws.findIndex(w => w.active);
    U.winActivate(ws[(i + 1) % ws.length].id);
  };
  const _tb = pcTaskbar;
  pcTaskbar = function () {
    // Feed the design's own taskbar with real windows, then wire the buttons to them.
    const save = pcWins.slice(), saveAct = pcAct;
    pcWins.splice(0, pcWins.length, ...WINS.map(w => ({ app: keyOf(w), desk: pcDesk, min: w.min, real: w })));
    const act = WINS.find(w => w.active);
    pcAct = act ? pcWins.find(x => x.real === act) : null;
    _tb();
    pcWins.splice(0, pcWins.length, ...save);
    pcAct = saveAct;
    document.querySelectorAll('#pctbc .ptb.app').forEach(b => {
      const a = b.dataset.a;
      b.oncontextmenu = e => {
        e.preventDefault(); e.stopPropagation();
        const ws = WINS.filter(w => keyOf(w) === a);
        pcCtx(e, [{ t: PAPPS[a].n, ic: 'app', f: () => PAPPS[a].open ? (REAL[a] ? U.spawn(REAL[a].exec) : PAPPS[a].open()) : 0 }]
          .concat(ws.length ? [{ sep: 1 }, { t: ws.length > 1 ? 'Close all windows' : 'Close window', ic: 'close', f: () => ws.forEach(w => U.winClose(w.id)) }] : []));
      };
    });
  };

  // ---- bar surface: only the visible parts take clicks; reserve the taskbar space ----
  if (SURF === 'bar') {
    let last = '';
    const vis = el => el && getComputedStyle(el).display !== 'none' && getComputedStyle(el).visibility !== 'hidden';
    const box = el => { const r = el.getBoundingClientRect(); return { x: r.left, y: r.top, w: r.width, h: r.height }; };
    setInterval(() => {
      const full = pcStart || pcFly || vis($('#pcctx')) || (typeof dgOn !== 'undefined' && dgOn) ||
        $('#pclock').classList.contains('on') || $('#pctv').classList.contains('on');
      let rects;
      if (full) rects = [{ x: 0, y: 0, w: innerWidth, h: innerHeight }];
      else {
        rects = [box($('#pctb'))];
        const t = $('#toast');
        if (t.classList.contains('show')) rects.push(box(t));
        document.querySelectorAll('#nwrap > *').forEach(n => { if (vis(n)) rects.push(box(n)); });
      }
      const key = JSON.stringify(rects.map(r => [r.x, r.y, r.w, r.h].map(Math.round)));
      if (key !== last) { last = key; U.setInput(rects); }
    }, 120);
    let ex = -1;
    const reserve = () => { const px = Math.ceil(innerHeight - $('#pctb').getBoundingClientRect().top); if (px !== ex) { ex = px; U.setExclusive(px); } };
    setInterval(reserve, 1000);
    reserve();
  }

  // ---- system state (same switches as Console Mode) ----
  let st = { vol, wifi, bt };
  setInterval(() => {
    if (vol !== st.vol) U.setVolume(vol);
    if (wifi !== st.wifi) U.setWifi(wifi);
    if (bt !== st.bt) U.setBt(bt);
    st = { vol, wifi, bt };
  }, 400);
  U.volume(v => { if (typeof v === 'number' && v >= 0) { vol = v; st.vol = v; } });
  U.net(o => { if (o && Array.isArray(o.nets)) { WIFI.nets = o.nets; WIFI.cur = o.current || null; } });
  refresh();
})();
