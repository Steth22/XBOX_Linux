#!/usr/bin/env bash
# Builds the Windows (x64) UraxOS simulator zip from the current mockup.
# Needs Node.js 18+ and internet access (downloads Electron once). Output: sim/dist/UraxOS-<version>-windows.zip
set -euo pipefail
cd "$(dirname "$0")"
VER=$(node -p "require('./package.json').version")
ELECTRON=45.4.1
rm -rf app dist && mkdir -p app dist
cp ../design/console-mockup-v5-latest.html app/index.html
[ -d node_modules/@electron/packager ] || npm i --no-save --no-audit --no-fund @electron/packager@20 resedit pe-library
# Download Electron for Windows with curl (works behind proxies) and verify its SHA-256.
ZDIR="${ELECTRON_ZIP_DIR:-$HOME/.cache/uraxos-electron}"; mkdir -p "$ZDIR"
ZIP="electron-v$ELECTRON-win32-x64.zip"; BASE="https://github.com/electron/electron/releases/download/v$ELECTRON"
[ -f "$ZDIR/$ZIP" ] || curl -fL --retry 3 -o "$ZDIR/$ZIP" "$BASE/$ZIP"
curl -fsSL "$BASE/SHASUMS256.txt" | grep " \*\?$ZIP\$" | sed 's/ \*\?/  /' | (cd "$ZDIR" && sha256sum -c -)
npx electron-packager . UraxOS --platform=win32 --arch=x64 --electron-version="$ELECTRON" \
  --electron-zip-dir="$ZDIR" --out=dist --overwrite --asar --app-version="$VER" \
  --ignore='^/(dist|tools|package|node_modules|build\.sh|README\.md)($|/)'
node tools/set-exe-info.mjs dist/UraxOS-win32-x64/UraxOS.exe icon.ico "$VER"
OUT="dist/UraxOS-$VER-windows"
mkdir -p "$OUT"
cp -r dist/UraxOS-win32-x64 "$OUT/UraxOS"
cp package/uninstall.ps1 "package/Uninstall UraxOS.cmd" "$OUT/UraxOS/"
cp package/install.ps1 "package/Install UraxOS.cmd" package/INSTALL.txt package/README-AR.txt "$OUT/"
(cd dist && zip -qr9 "UraxOS-$VER-windows.zip" "UraxOS-$VER-windows")
ls -lh "dist/UraxOS-$VER-windows.zip"
