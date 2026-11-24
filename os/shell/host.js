// UraxOS host glue: runs after the UI page loads and wires the design to the real Linux system.
(function () {
  if (!window.urax || window.urax.host !== 'uraxos') return;
  const U = window.urax;
  const fileUrl = p => 'file://' + p.split('/').map(encodeURIComponent).join('/');
  const steamArt = (id, f) => 'https://cdn.cloudflare.steamstatic.com/steam/apps/' + id + '/' + f;

  // Extra icons for real apps (same stroke style as the design icons).
  const svg = p => '<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">' + p + '</svg>';
  I.web = svg('<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/>');
  I.files = svg('<path d="M3 6.5A1.5 1.5 0 0 1 4.5 5H9l2 2h8.5A1.5 1.5 0 0 1 21 8.5v9A1.5 1.5 0 0 1 19.5 19h-15A1.5 1.5 0 0 1 3 17.5z"/>');
  I.game = svg('<rect x="2.5" y="7" width="19" height="10" rx="5"/><path d="M7 10v4M5 12h4"/><circle cx="16" cy="11" r=".6"/><circle cx="18" cy="13" r=".6"/>');

  // 1) Power on by itself: the real machine already booted.
  const pw = document.getElementById('pw');
  if (pw) setTimeout(() => pw.click(), 300);

  // 2) Real launches. Built-ins (Gallery, Library, PC Mode) stay inside the UI.
  const run = (name, exec) => { toast('Starting ' + name + '…'); U.launch(exec); };
  const _launch = launch;
  launch = function (i, obj) {
    const a = obj || apps[i];
    if (a && a.exec) { run(a.n, a.exec); return; }
    return _launch(i, obj);
  };
  pcOpen = function () { qpClose(); toast('Switching to PC Mode'); U.pcMode(); };
  libRun = function (it) {
    if (it.exec) { libClose(); run(it.n, it.exec); return; }
    toast(it.n + ' is not installed');
  };
  const _libCov = libCov;
  libCov = function (it) {
    if (it.sid) return "center/cover no-repeat url('" + steamArt(it.sid, 'library_600x900.jpg') + "'),linear-gradient(160deg," + it.c[0] + ',' + it.c[1] + ')';
    return _libCov(it);
  };

  const _libGlyph = libGlyph;
  libGlyph = it => it.sid ? '' : _libGlyph(it);

  // 3) Restart: the design calls urax.reboot() itself.

  // 4) Home tiles and Library from the installed apps and Steam games.
  const PAL = [['#4FB3F6', '#1d3a6a'], ['#e8503a', '#3a0f14'], ['#7cc86a', '#2b6a3a'], ['#e86aa8', '#5a2a7a'], ['#ffb04f', '#3a2a1a']];
  U.apps(list => {
    if (!Array.isArray(list)) return;
    const items = list.map((x, k) => ({
      n: x.n, k: x.k, src: x.src, exec: x.exec, sid: x.sid, inst: 1, last: 0, hrs: 0, gb: x.gb || 0,
      key: x.exec && x.exec.startsWith('firefox') ? 'web' : (x.k === 'game' ? 'game' : undefined),
      c: PAL[k % PAL.length]
    }));
    LIB.splice(0, LIB.length, ...items);

    const by = n => list.find(x => x.exec && x.exec.split(' ')[0] === n);
    const tiles = [apps.find(a => a.i === 'gallery')];
    list.filter(x => x.src === 'steam').slice(0, 2).forEach((g, k) => {
      const key = 'st' + g.sid;
      ART[key] = { t: steamArt(g.sid, 'header.jpg'), b: steamArt(g.sid, 'library_hero.jpg') };
      tiles.push({ n: g.n, s: 'From Steam', exec: g.exec, i: key, c: PAL[k], bg: 'linear-gradient(160deg,#162536,#0B1220 75%)' });
    });
    const steam = apps.find(a => a.i === 'steam'), st = by('steam');
    if (st) tiles.push(Object.assign({}, steam, { exec: st.exec }));
    const ff = by('firefox');
    if (ff) tiles.push({ n: 'Firefox', s: 'Web browser', exec: ff.exec, i: 'web', c: ['#ff7a3d', '#7a2a8a'], bg: 'radial-gradient(70% 60% at 70% 30%,#ff7a3d55,transparent 70%),linear-gradient(160deg,#2a1430,#0b0d14 75%)' });
    const fm = by('dolphin');
    if (fm) tiles.push({ n: 'Files', s: 'Your files', exec: fm.exec, i: 'files', c: ['#4FB3F6', '#1d5a8a'], bg: 'radial-gradient(70% 60% at 50% 30%,#4FB3F655,transparent 70%),linear-gradient(160deg,#10243a,#0b0d14 75%)' });
    tiles.push(apps.find(a => a.i === 'lib'), apps.find(a => a.i === 'pc'));
    apps.splice(0, apps.length, ...tiles.filter(Boolean));
    track.innerHTML = '';
    apps.forEach(mkTile);
    go(Math.min(1, apps.length - 1), true);
  });

  // 5) Gallery from ~/Pictures/Screenshots; screenshots are real files.
  function addPic(p, front) {
    GSRC.push(fileUrl(p.path));
    const it = { id: ++gseq, t: 'img', g: 'Screenshots', m: Math.max(0, Math.round((Date.now() - p.mtime) / 60000)), s: GSRC.length - 1 };
    front ? GAL.unshift(it) : GAL.push(it);
  }
  U.pictures(list => {
    GAL.splice(0, GAL.length);
    (list || []).forEach(p => addPic(p));
  });
  galAddShot = function () {
    U.screenshot(path => { if (path) addPic({ path, mtime: Date.now() }, true); else toast('Screenshot failed'); });
  };

  // 6) Volume, Wi-Fi radio and Bluetooth follow the UI switches.
  let last = { vol, wifi, bt };
  setInterval(() => {
    if (vol !== last.vol) U.setVolume(vol);
    if (wifi !== last.wifi) U.setWifi(wifi);
    if (bt !== last.bt) U.setBt(bt);
    last = { vol, wifi, bt };
  }, 400);
  U.volume(v => { if (typeof v === 'number' && v >= 0) { vol = v; last.vol = v; } });

  // 7) Real Wi-Fi networks (NetworkManager).
  function loadNets(done) {
    U.net(o => {
      if (!o || !Array.isArray(o.nets)) return done && done();
      WIFI.nets = o.nets;
      WIFI.cur = o.current || null;
      if (o.wired === 'connected' || o.current) { wifi = true; last.wifi = true; }
      stat();
      done && done();
    });
  }
  loadNets();
  wifiScan = function () {
    WIFI.scan = true; sDraw();
    loadNets(() => { WIFI.scan = false; if (setOpen) sDraw(); });
  };
  function connect(n, pw) {
    toast('Connecting to ' + n.s + '…');
    U.wifiConnect(n.s, pw, r => {
      if (r === 'ok') { WIFI.cur = n.s; n.saved = 1; wifi = true; stat(); toast('Connected to ' + n.s); }
      else toast('Could not connect to ' + n.s);
      if (setOpen) sDraw();
    });
  }
  wifiConnect = n => connect(n, '');
  wifiJoin = function (n) {
    if (!n.lock || n.saved) { connect(n, ''); return; }
    dgOpen({ t: 'Connect to ' + n.s, x: 'Enter the network password', input: { ph: 'Password', pw: 1 }, btns: [
      { t: 'Connect', f() { const v = $('#dgin').value; if (v.length < 8) { dgC.err = 'Wi-Fi passwords have at least 8 characters.'; dgDraw(); return; } dgClose(); connect(n, v); } },
      { t: 'Cancel', dn: 1, f() { dgClose(); } }] });
  };
})();
