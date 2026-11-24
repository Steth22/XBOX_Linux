#!/bin/bash
# Turns disk.raw into a compressed VMDK plus the Windows setup scripts, zipped for delivery.
set -euo pipefail
IMG=$1; HERE=$(cd "$(dirname "$0")" && pwd); DIST=${DIST:-$(dirname "$IMG")/dist}
rm -rf "$DIST/UraxOS-alpha"; mkdir -p "$DIST/UraxOS-alpha"
qemu-img convert -p -O vmdk -o subformat=streamOptimized "$IMG" "$DIST/UraxOS-alpha/UraxOS-alpha.vmdk"
cp "$HERE"/package/* "$DIST/UraxOS-alpha/"
(cd "$DIST" && rm -f UraxOS-alpha.zip && zip -0 -r UraxOS-alpha.zip UraxOS-alpha >/dev/null)
echo "$DIST/UraxOS-alpha.zip"
