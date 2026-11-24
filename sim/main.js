// UraxOS simulator host (Electron). Loads the self-contained mockup and adds desktop behavior:
// fullscreen by default (--windowed for a window), F11 toggles fullscreen, Alt+F4 is passed to the UI
// first (it closes the active PC Mode window), and "Shut down" inside UraxOS quits the app.
const { app, BrowserWindow, ipcMain, Menu } = require('electron');
const path = require('path');
const os = require('os');

const windowed = process.argv.includes('--windowed');
let win = null;
let quitting = false;
let lastAltF4 = 0;

if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.on('second-instance', () => {
    if (!win) return;
    if (win.isMinimized()) win.restore();
    win.focus();
  });
  app.whenReady().then(createWindow);
}

function createWindow() {
  Menu.setApplicationMenu(null);
  win = new BrowserWindow({
    width: 1600,
    height: 900,
    minWidth: 960,
    minHeight: 540,
    fullscreen: !windowed,
    backgroundColor: '#000000',
    title: 'UraxOS',
    icon: path.join(__dirname, 'icon.ico'),
    autoHideMenuBar: true,
    show: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      backgroundThrottling: false,
      spellcheck: false,
    },
  });
  win.once('ready-to-show', () => { win.show(); win.focus(); });
  win.loadFile(path.join(__dirname, 'app', 'index.html'));
  win.webContents.setVisualZoomLevelLimits(1, 1);
  win.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
  win.webContents.on('will-navigate', (e, url) => { if (!url.startsWith('file:')) e.preventDefault(); });

  win.webContents.on('before-input-event', (e, input) => {
    if (input.type !== 'keyDown') return;
    const key = input.key;
    if (key === 'F4' && input.alt) { lastAltF4 = Date.now(); e.preventDefault(); win.webContents.send('altf4'); return; }
    if (key === 'F11') { e.preventDefault(); win.setFullScreen(!win.isFullScreen()); return; }
    if (input.control && ['=', '-', '+', '0'].includes(key)) { e.preventDefault(); return; }
    if (input.control && input.shift && key.toLowerCase() === 'i') { e.preventDefault(); win.webContents.toggleDevTools(); }
  });

  // Windows may still turn Alt+F4 into a close request: let the UI decide in that case too.
  win.on('close', (e) => {
    if (quitting) return;
    if (Date.now() - lastAltF4 < 600) { e.preventDefault(); }
  });
}

ipcMain.on('quit', () => { quitting = true; app.quit(); });
// Real hardware facts for Settings > About and Task Manager.
ipcMain.on('sysinfo', (e) => {
  const cpus = os.cpus();
  const winVer = process.platform === 'win32' ? (Number(os.release().split('.')[2]) >= 22000 ? 'Windows 11' : 'Windows 10') : os.type();
  e.returnValue = {
    cpu: cpus.length ? cpus[0].model.replace(/\s+/g, ' ').trim() : 'CPU',
    threads: cpus.length,
    memGB: Math.round(os.totalmem() / 1073741824),
    host: winVer + ' (' + os.arch() + ')',
  };
});
app.on('window-all-closed', () => app.quit());
