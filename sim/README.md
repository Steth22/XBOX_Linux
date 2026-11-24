# UraxOS simulator (Windows app)

Wraps `design/console-mockup-v5-latest.html` in Electron so the owner can run UraxOS on a Windows 11 PC:
fullscreen (or `--windowed`), offline, real gamepad support (Gamepad API, standard mapping), saved state
(localStorage in `%APPDATA%\UraxOS`), real clock/battery/CPU/GPU/RAM info, Shut down quits the app.

- `main.js` / `preload.js`: Electron host (F11 fullscreen toggle, Alt+F4 routed to the UI, `sysinfo` bridge).
- `package/`: Windows installer (`Install UraxOS.cmd` + `install.ps1`, per-user, Start menu shortcuts),
  uninstaller, `INSTALL.txt` (English) and `README-AR.txt` (Arabic steps).
- `tools/`: icon generator and exe resource editor (pure JS, no Wine).
- Build: `./build.sh` (Node 18+, internet once). Output: `dist/UraxOS-<version>-windows.zip`.
