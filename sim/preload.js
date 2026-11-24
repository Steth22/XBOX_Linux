// Small, safe bridge between the UraxOS page and the desktop host.
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('urax', {
  host: 'electron',
  quit: () => ipcRenderer.send('quit'),
  onAltF4: (cb) => ipcRenderer.on('altf4', () => cb()),
  sys: () => ipcRenderer.sendSync('sysinfo'),
});
