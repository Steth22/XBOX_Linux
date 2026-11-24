#!/bin/bash
# Configures an UraxOS root filesystem. Run INSIDE the target (arch-chroot).
# Expects: /usr/src/uraxos/{shell,ui,files} copied in by build.sh.
set -euo pipefail
SRC=/usr/src/uraxos
USER_NAME=urax
USER_PASS=urax

# --- Base system ---
echo uraxos > /etc/hostname
printf '127.0.0.1 localhost\n::1 localhost\n127.0.1.1 uraxos\n' > /etc/hosts
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen >/dev/null
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
ln -sf /usr/share/zoneinfo/Asia/Riyadh /etc/localtime
echo 'KEYMAP=us' > /etc/vconsole.conf

# --- User ---
id "$USER_NAME" >/dev/null 2>&1 || useradd -m -G wheel,audio,video,input -s /bin/bash -c "UraxOS" "$USER_NAME"
echo "$USER_NAME:$USER_PASS" | chpasswd
echo "root:$USER_PASS" | chpasswd
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel
chmod 440 /etc/sudoers.d/10-wheel

# --- urax-shell (Console Mode) ---
cmake -S "$SRC/shell" -B /tmp/urax-build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr >/dev/null
cmake --build /tmp/urax-build -j"$(nproc)" >/dev/null
cmake --install /tmp/urax-build >/dev/null
install -d /usr/share/uraxos/ui
install -m644 "$SRC/ui/index.html" /usr/share/uraxos/ui/index.html
install -m644 "$SRC/shell/bridge.js" "$SRC/shell/host.js" "$SRC/shell/host-pc.js" /usr/share/uraxos/ui/
install -m644 "$SRC/files/wallpaper.png" /usr/share/uraxos/wallpaper.png

cat > /etc/xdg/autostart/uraxos-shell.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=UraxOS Console Mode
Exec=urax-shell
X-KDE-autostart-phase=2
NoDisplay=true
EOF
cat > /etc/xdg/autostart/uraxos-desktop.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=UraxOS PC Mode
Exec=urax-shell --desktop
X-KDE-autostart-phase=1
NoDisplay=true
EOF
# KWin only lets known programs list windows: declare it for urax-shell.
cat > /usr/share/applications/uraxos-shell.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Console Mode
Comment=UraxOS console interface
Exec=/usr/bin/urax-shell
Icon=input-gamepad
Categories=System;
X-KDE-Wayland-Interfaces=org_kde_plasma_window_management,org_kde_kwin_keystate
EOF
rm -f /usr/share/applications/uraxos-console.desktop
# Our PC Mode replaces the Plasma desktop shell (KWin stays as the window engine).
install -d /etc/systemd/user
ln -sf /dev/null /etc/systemd/user/plasma-plasmashell.service

# --- Session: autologin straight into Plasma (Wayland) ---
cat > /etc/greetd/config.toml <<EOF
[terminal]
vt = 1

[default_session]
command = "agreety --cmd '/usr/lib/plasma-dbus-run-session-if-needed /usr/bin/startplasma-wayland'"
user = "greeter"

[initial_session]
command = "/usr/lib/plasma-dbus-run-session-if-needed /usr/bin/startplasma-wayland"
user = "$USER_NAME"
EOF

# --- PC Mode look (Urax theme on top of Breeze Dark) ---
SK=/etc/skel/.config
install -d "$SK"
install -Dm644 "$SRC/files/Urax.colors" /usr/share/color-schemes/Urax.colors
awk '/^\[/{skip=($0=="[General]"||$0=="[KDE]")} !skip' "$SRC/files/Urax.colors" > "$SK/kdeglobals"
cat >> "$SK/kdeglobals" <<'EOF'
[General]
AccentColor=79,179,246
ColorScheme=Urax

[KDE]
LookAndFeelPackage=org.kde.breezedark.desktop
SingleClick=false
EOF
printf '[Daemon]\nAutolock=false\nLockOnResume=false\n' > "$SK/kscreenlockerrc"
printf '[Wallet]\nEnabled=false\nFirst Use=false\n' > "$SK/kwalletrc"
printf '[General]\nloginMode=emptySession\n' > "$SK/ksmserverrc"
printf '[Plugins]\nbaloofileEnabled=false\n' > "$SK/kded5rc"
printf '[Basic Settings]\nIndexing-Enabled=false\n' > "$SK/baloofilerc"
cat > "$SK/powerdevilrc" <<'EOF'
[AC][SuspendAndShutdown]
AutoSuspendAction=0
[AC][Display]
TurnOffDisplayWhenIdle=false
DimDisplayWhenIdle=false
EOF

rm -f /etc/xdg/autostart/uraxos-firstlogin.desktop /usr/bin/urax-firstlogin

# Re-apply skel to the user created before the files existed.
rm -f /etc/skel/Desktop/uraxos-console.desktop "/home/$USER_NAME/Desktop/uraxos-console.desktop"
cp -rT /etc/skel "/home/$USER_NAME"
chown -R "$USER_NAME:$USER_NAME" "/home/$USER_NAME"
install -d -o "$USER_NAME" -g "$USER_NAME" "/home/$USER_NAME/Pictures/Screenshots"

# --- Services ---
systemctl enable NetworkManager bluetooth greetd >/dev/null 2>&1
systemctl enable vboxservice >/dev/null 2>&1 || true
systemctl set-default graphical.target >/dev/null

# --- Boot: fstab + generic initramfs (no autodetect, image must boot anywhere) ---
cat > /etc/fstab <<'EOF'
LABEL=uraxroot  /      ext4  rw,noatime  0 1
LABEL=URAXESP   /boot  vfat  rw,umask=0077  0 2
EOF
sed -i 's/^HOOKS=.*/HOOKS=(base systemd modconf kms keyboard sd-vconsole block filesystems fsck)/' /etc/mkinitcpio.conf
sed -i 's/^PRESETS=.*/PRESETS=(default)/' /etc/mkinitcpio.d/linux.preset
mkinitcpio -P >/dev/null 2>&1 || mkinitcpio -P

# --- Clean build tools and caches ---
rm -rf /tmp/urax-build
[ -n "${KEEP_TOOLS:-}" ] || pacman -Rns --noconfirm cmake gcc make pkgconf >/dev/null 2>&1 || true
pacman -Scc --noconfirm >/dev/null 2>&1 || true
echo "configure: done"
