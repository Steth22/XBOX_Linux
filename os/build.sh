#!/bin/bash
# Builds the UraxOS alpha disk image (UEFI, GPT) from an Arch bootstrap, on any Linux host with root.
# Output: $OUT/disk.raw, then images/UraxOS-alpha.vmdk + UraxOS-alpha.ova (VirtualBox).
# Host tools: curl zstd sfdisk mkfs.vfat mkfs.ext4 mtools qemu-img losetup.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${OUT:-/var/tmp/ux}
B=$OUT/root.x86_64
MIRROR=${MIRROR:-https://geo.mirror.pkgbuild.com}
PKGS=(base linux mkinitcpio sudo nano less networkmanager bluez bluez-utils
  pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber alsa-utils
  mesa lib32-mesa vulkan-swrast lib32-vulkan-swrast vulkan-icd-loader lib32-vulkan-icd-loader
  qt6-base qt6-webengine qt6-webchannel qt6-wayland qt6-declarative greetd
  plasma-desktop plasma-workspace kwin plasma-nm plasma-pa kscreen breeze breeze-gtk kde-gtk-config
  powerdevil bluedevil systemsettings dolphin konsole kwrite gwenview ark spectacle plasma-systemmonitor
  xdg-desktop-portal-kde phonon-qt6-vlc xorg-xwayland firefox ttf-liberation noto-fonts steam flatpak
  virtualbox-guest-utils cmake gcc make pkgconf)

mkdir -p "$OUT"
# 1) Arch bootstrap environment
if [ ! -x "$B/usr/bin/pacman" ]; then
  curl -fL "$MIRROR/iso/latest/archlinux-bootstrap-x86_64.tar.zst" -o "$OUT/bootstrap.tar.zst"
  tar --zstd -xf "$OUT/bootstrap.tar.zst" -C "$OUT" --numeric-owner
  echo "Server = $MIRROR/\$repo/os/\$arch" > "$B/etc/pacman.d/mirrorlist"
  sed -i -e '/^#\[multilib\]/,+1 s/^#//' -e 's/^#ParallelDownloads.*/ParallelDownloads = 6/' "$B/etc/pacman.conf"
fi
mountpoint -q "$B" || mount --bind "$B" "$B"
mountpoint -q "$B/proc" || mount -t proc proc "$B/proc"
mountpoint -q "$B/sys" || mount --rbind /sys "$B/sys"
mountpoint -q "$B/dev" || mount --rbind /dev "$B/dev"
mountpoint -q "$B/run" || mount -t tmpfs tmpfs "$B/run"
cp -L /etc/resolv.conf "$B/etc/resolv.conf"
CH() { chroot "$B" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin \
  https_proxy="${https_proxy:-}" HTTPS_PROXY="${HTTPS_PROXY:-}" no_proxy="${no_proxy:-}" /bin/bash -c "$1"; }

# 2) Disk: 1 MiB BIOS gap, 512 MiB ESP, rest ext4 root
IMG=$OUT/disk.raw
rm -f "$IMG"; truncate -s 32G "$IMG"
sfdisk "$IMG" <<'EOF'
label: gpt
start=2048, size=1048576, type=U, name="URAXESP"
start=1050624, type=L, name="uraxroot"
EOF
ESP_OFF=$((2048*512)); ESP_SIZE=$((1048576*512)); ROOT_OFF=$((1050624*512))
ESP=$(losetup -f --show -o $ESP_OFF --sizelimit $ESP_SIZE "$IMG")
ROOT=$(losetup -f --show -o $ROOT_OFF "$IMG")
mkfs.vfat -F32 -n URAXESP "$ESP" >/dev/null
mkfs.ext4 -q -L uraxroot "$ROOT"
mount "$ROOT" "$B/mnt"

# 3) Install packages and configure (configure.sh runs inside the target)
CH "pacman-key --init >/dev/null && pacman-key --populate archlinux >/dev/null && pacstrap -K -C /etc/pacman.conf /mnt ${PKGS[*]}"
install -d "$B/mnt/usr/src/uraxos/ui"
cp -r "$HERE/shell" "$HERE/rootfs/files" "$B/mnt/usr/src/uraxos/"
cp "$HERE/rootfs/configure.sh" "$B/mnt/usr/src/uraxos/"
cp "$HERE/../design/console-mockup-v5-latest.html" "$B/mnt/usr/src/uraxos/ui/index.html"
CH "arch-chroot /mnt bash /usr/src/uraxos/configure.sh"

# 4) ESP: systemd-boot + kernel (vfat is filled with mtools, no mount needed)
T=$B/mnt; export MTOOLS_SKIP_CHECK=1
mmd -i "$ESP" ::/EFI ::/EFI/BOOT ::/EFI/systemd ::/loader ::/loader/entries
mcopy -o -i "$ESP" "$T/usr/lib/systemd/boot/efi/systemd-bootx64.efi" ::/EFI/BOOT/BOOTX64.EFI
mcopy -o -i "$ESP" "$T/usr/lib/systemd/boot/efi/systemd-bootx64.efi" ::/EFI/systemd/systemd-bootx64.efi
mcopy -o -i "$ESP" "$HERE/rootfs/boot/loader.conf" ::/loader/loader.conf
mcopy -o -i "$ESP" "$HERE/rootfs/boot/uraxos.conf" ::/loader/entries/uraxos.conf
mcopy -o -i "$ESP" "$T/boot/vmlinuz-linux" "$T/boot/initramfs-linux.img" ::/
pkill -f "gpg-agent --homedir /mnt" || true
sync; umount "$B/mnt"; e2fsck -fp "$ROOT" || true
losetup -d "$ESP" "$ROOT"

# 5) VirtualBox package
"$HERE/vbox/make-ova.sh" "$IMG"
