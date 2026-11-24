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
    onAltF4: cb => { window.__uraxAltF4 = cb; }
  };
  function init() {
    if (!window.qt || !window.QWebChannel) return;
    new QWebChannel(qt.webChannelTransport, ch => {
      api = ch.objects.sys;
      api.altF4.connect(() => window.__uraxAltF4 && window.__uraxAltF4());
      q.splice(0).forEach(x => call(...x));
    });
  }
  if (window.qt && window.QWebChannel) init(); else document.addEventListener('DOMContentLoaded', init);
})();
