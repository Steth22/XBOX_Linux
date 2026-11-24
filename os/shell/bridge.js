// UraxOS bridge: exposes window.urax to the UI, backed by the Qt "sys" object over QWebChannel.
(function () {
  const q = [];
  let api = null;
  const J = cb => r => { if (!cb) return; try { cb(typeof r === 'string' && r ? JSON.parse(r) : r); } catch (e) { cb(r); } };
  function call(m, args, cb) { if (api) api[m](...args, cb || (() => {})); else q.push([m, args, cb]); }
  window.urax = {
    host: 'uraxos',
    sys: () => window.__URAX_SYS,
    quit: () => call('quit', []),
    reboot: () => call('reboot', []),
    pcMode: () => call('pcMode', []),
    launch: c => call('launch', [c]),
    setVolume: v => call('setVolume', [v]),
    volume: cb => call('volume', [], cb),
    setWifi: b => call('setWifi', [!!b]),
    setBt: b => call('setBt', [!!b]),
    net: cb => call('net', [], J(cb)),
    wifiConnect: (s, p, cb) => call('wifiConnect', [s, p || ''], cb),
    apps: cb => call('apps', [], J(cb)),
    screenshot: cb => call('screenshot', [], cb),
    pictures: cb => call('pictures', [], J(cb)),
    onAltF4: cb => { window.__uraxAltF4 = cb; },
    mode: () => (window.__URAX_SYS || {}).mode,
    surface: () => (window.__URAX_SYS || {}).surface,
    spawn: c => call('spawn', [c]),
    consoleMode: () => call('consoleMode', []),
    windows: cb => call('windows', [], J(cb)),
    winToggle: id => call('winToggle', [id]),
    winActivate: id => call('winActivate', [id]),
    winMinimize: id => call('winMinimize', [id]),
    winClose: id => call('winClose', [id]),
    showDesktop: on => call('showDesktop', [!!on]),
    setInput: rects => call('setInput', [JSON.stringify(rects)]),
    setExclusive: px => call('setExclusive', [Math.round(px)]),
    onWindows: cb => { window.__uraxWin = cb; }
  };
  function init() {
    if (!window.qt || !window.QWebChannel) return;
    new QWebChannel(qt.webChannelTransport, ch => {
      api = ch.objects.sys;
      api.altF4.connect(() => window.__uraxAltF4 && window.__uraxAltF4());
      if (api.windowsChanged) api.windowsChanged.connect(() => window.__uraxWin && window.__uraxWin());
      q.splice(0).forEach(x => call(...x));
    });
  }
  if (window.qt && window.QWebChannel) init(); else document.addEventListener('DOMContentLoaded', init);
})();
