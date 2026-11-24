# Project: UraxOS, a Custom Dual-Mode OS Shell (Plan v4)

You are helping me build **UraxOS**, a private/personal Linux-based OS shell and system image. It is a personal project
for me and my circle, not a commercial product.

**Targets**
1. **Primary target: a normal x86-64 PC** (UEFI, installable from USB, optional dual boot).
2. **Optional secondary target: jailbroken PS4 Slim** (firmware 13.52, GoldHEN). This is a "bonus" port, done only after the PC version works.

**Scope rule:** Do NOT write or explain exploit/jailbreak code or how any jailbreak entry point works.
For the PS4 target, assume GoldHEN and BinLoader are already running and use existing community Linux loaders/kernels.

You can talk to me in Arabic or English. Keep code, comments, and docs in English.

---

## 1. Identity and design

- **Owner name:** Urax. **System name:** UraxOS.
- **Logo (current direction, final art pending):** a bold rounded capital "U" in blue; a sharp four-point sparkle inside the U's counter space; a smooth tapering diagonal swoosh running from the sparkle toward the bottom-right, crossing in front of the right arm of the U with a clean gap where it passes over. The sparkle must be a perfect four-point star with identical arms and sharp tips; its rotation angle (0 degrees, 12 degrees or 45 degrees) is still being chosen. Treat the logo as a swappable asset.
- **Official color:** slightly light blue, **Urax Blue `#4FB3F6`** (my sketch used a more saturated blue around `#0A9BFF`; confirm with me before changing the theme).
- **Palette:** Deep Space `#0B1220` (background), Surface `#121B2E` (cards), Mist `#E8F1FB` (text), Muted `#9FB3C8` (secondary text), Border `#2A3A55`.
- **Fonts:** Space Grotesk (headings, wordmark), Inter (body), with system fallbacks.
- **Theme:** dark by default (TV and desk friendly). Colors, fonts, radii and logo live in a swappable theme layer.
- **Design reference:** https://claude.ai/artifact/1MKLd8stepFL3Vu3GbHfK6
- Safety, security and antivirus design will be discussed later (see 5.4).

---

## 2. Vision

I boot or launch UraxOS and get one system with two modes.

**Console Mode**: behaves like a game console, with my own design.
- Fullscreen, controller-first launcher
- Quick menu (overlay, openable from anywhere)
- Screenshots and video recording (Share button shortcut)
- Notifications center
- Photo gallery
- System updates
- Game library on the home screen (PC games and console-style apps together)

**PC Mode**: behaves like Windows, with my own design.
- Taskbar, start menu, window management
- File Explorer
- Task Manager (processes, CPU, RAM, GPU, temperature)
- Install and run apps: Steam, Discord, browsers, other games
- Linux-native apps, Flatpak apps, and Windows apps/games through Proton/Wine where they work
- Realistic goal: "most things a normal Linux PC can do", not literally everything Windows can do

Switching between modes is fast and needs no reboot.

---

## 3. Base system strategy

Do not build an OS from scratch. Build UraxOS **on top of an existing Linux base**.
- First, evaluate existing gaming-oriented distributions (for example Bazzite, ChimeraOS, SteamOS-like images) and a plain Arch or Fedora base, then **recommend one with trade-offs and wait for my approval**.
- UraxOS = base image + our Wayland shell (Console Mode and PC Mode) + services (network, Bluetooth, audio, updates) + theme layer + installer/branding.
- Use Flatpak for apps where possible, so the base stays clean and updates are safe.

---

## 4. Development strategy: PC first, hardware abstraction always

1. Develop and test everything in a **VM (QEMU)** and on a real PC.
2. Every hardware-related module has an interface with a **mock** (VM/tests) and **real** implementations per target: `pc` (default) and `ps4` (optional, later).
3. Console Mode and PC Mode never contain target-specific code.
4. Each phase ends with a "verify on real hardware" checklist.

### PC target details
- Installable ISO, UEFI boot, installer with: full-disk install, **dual boot beside Windows**, and a **live USB** mode (try without installing).
- GPU support: AMD and Intel (open Mesa drivers) and NVIDIA (proprietary driver, Wayland) must all be considered; document known issues.
- Secure Boot: document the approach (signed shim or instructions to disable).
- Never touch other disks without an explicit, confirmed selection.

### PS4 target details (optional, later)
- Console: PS4 Slim, HEN 13.52, GoldHEN v2.4b18.12, southbridge **Belize2 A0 (0x40100)**.
- The jailbreak is tethered: after a full power-off GoldHEN must be loaded again; Rest Mode keeps it.
- Belize2 on Slim is the least-proven PS4 Linux combination. Black screens and missing Wi-Fi have been reported; some kernel builds claim CUH-2115B works. Treat as **unverified**.
- Candidate community builds to try, one at a time: feeRnt `ps4-linux-12xx` (5.15.15-belize, then 6.15.4 aeolia-belize), X-F1REBALL Arch KDE (Belize kernel, tested on 13.52), and the Baikal kernel as a last resort.
- Black screen playbook: wait 1 to 2 minutes; set 1080p, HDR and Deep Color off, test HDCP both off and on; try switching TTY (Ctrl+Alt+F2 then F1/F7); add `bootargs.txt` next to the kernel; try the next kernel.
- Wired Ethernet is the baseline. Wi-Fi/Bluetooth depend on the chip and kernel build; keep a USB Wi-Fi/Bluetooth dongle as fallback (choose one with a known Linux chip).
- Boot from external USB/HDD only; never touch internal storage.
- Do not update the console firmware above 13.52.
- PS4 hardware is weak: favor light games, use Moonlight/Steam Link for heavy ones. Verify 3D acceleration (ps4-mesa) and Vulkan level before promising Proton games.
- Expect a 1 to 2 minute black screen at start; the launcher should say so.

---

## 5. Features

### 5.1 Core (required for a daily-usable system)
1. **Networking UI**: Wi-Fi and Ethernet scan, connect with password (on-screen keyboard), manual and automatic connection, saved networks, smooth switching. Build on NetworkManager over D-Bus.
2. **Bluetooth UI**: pair, connect, forget keyboards, mice, controllers and headphones. Build on BlueZ.
3. **Audio**: HDMI/speakers, Bluetooth headphones (A2DP, mic profile if possible), volume control, via PipeWire.
4. **Display settings**: resolution, refresh rate, scaling, HDR if feasible.
5. **On-screen keyboard** usable with a controller.
6. **Power**: shutdown, restart, screensaver/suspend (suspend only where reliable; on PS4 use a screensaver instead).
7. **Storage manager**: free space, move games between drives, clear cache.
8. **Unified settings app**: network, Bluetooth, audio, display, users, updates.
9. **Stability tooling**: watchdog, crash logs saved to a user-visible folder (USB-friendly on PS4).

### 5.2 Supported apps, games and accessories (must-have list)

| Item | Plan | Expectation |
|---|---|---|
| Brave | Flatpak or native package | Should work |
| Chrome / Chromium | Official package or Flatpak (Chromium) | Should work |
| Firefox | Native or Flatpak | Should work |
| Claude Desktop | No official Linux build. Provide Claude as a web app (claude.ai) in a dedicated app window; ask me before using any unofficial community build | Web app version |
| Steam | Native or Flatpak, with Proton | Should work on PC |
| Godot | Linux editor and exports | Should work |
| Unity | Unity Hub/Editor exist for Linux | PC: should work; PS4: editor best-effort |
| Minecraft | Java Edition via an official or open launcher (no official Bedrock for Linux) | Should work on PC |
| Stray, Peak | Steam + Proton | PC: should work; PS4: verify |
| PS4 controller (DualShock 4) | Bluetooth/USB, remap, rumble, gyro | Should work |
| Xbox controller | Bluetooth (xpadneo or similar) or USB | Should work |
| Wireless keyboard, mouse | Bluetooth or USB dongle | Should work |
| Wireless headphones | Bluetooth audio via PipeWire | Should work; verify latency |

Known limits: games with Windows-only anti-cheat will not run; some DRM or launcher quirks break Proton games.

### 5.3 Apps and games features
10. **Steam integration**: detect Steam and installed games (parse `libraryfolders.vdf` and `appmanifest_*.acf`), show them as tiles in Console Mode, launch through Steam, support Proton.
11. **Game streaming**: Moonlight and Steam Link.
12. **Emulators**: RetroArch as a section in Console Mode.
13. **Media apps**: local video player, YouTube/Netflix via browser.
14. **Performance modes**: power saver / balanced / max, plus an overlay with FPS, temperature and RAM.
15. **Controller remapping** per game.
16. **Remote control** from my phone, plus photo and file upload from the phone.
17. **User accounts** with parental controls and play-time limits.
18. **Backup and restore** for settings and game saves.
19. **Signed OTA updates** with rollback.

### 5.4 Later (design extension points now, implement later)
20. App store (Flatpak backend).
21. Switchable themes and animated wallpapers.
22. Advanced notification center and Discord voice chat inside Console Mode.
23. Security: sandboxed apps with a permission model, nftables firewall, optional ClamAV scanning.
24. Boot animation using the final logo.

---

## 6. Technical constraints

- **Stack:** Wayland compositor plus Qt/QML or similar. Propose the stack and justify it before using it. It must stay light enough for a PS4-class machine so the PS4 port remains possible.
- **Separation:** hardware-specific code isolated behind interfaces; the shell runs in QEMU/VM.
- **Safety:** installers and disk tools must be conservative, confirm destructive actions, and never touch disks the user did not select.
- **Logging:** write logs to a user-visible folder for debugging.

---

## 7. Roadmap

- **Phase 0 (PC):** dev environment, base image choice (with my approval), VM setup, project structure, hardware abstraction layer with mocks.
- **Phase 1 (PC):** minimal shell, controller navigation, theme layer using the UraxOS palette and logo.
- **Phase 2 (PC):** Console Mode in full (launcher, quick menu, notifications, gallery, screenshots, game library with mocked games).
- **Phase 3 (PC):** PC Mode (desktop, file explorer, task manager, browsers via Flatpak).
- **Phase 4 (PC):** Steam library integration, settings app, networking and Bluetooth UI, audio, display.
- **Phase 5 (PC):** installer ISO, live USB, dual boot, GPU support matrix, first real-PC tests.
- **Phase 6 (PC):** performance modes, streaming, emulators, verify the 5.2 compatibility table.
- **Phase 7:** updates with rollback, backups, users, security, boot animation, final logo.
- **Phase 8 (optional, PS4):** hardware sanity check with community Linux builds on my console (display, input, Ethernet, Wi-Fi/Bluetooth, memory size), record results in `docs/hardware-report.md`, then add a `ps4` target and a launcher app.

---

## 8. How to work

1. **First**, inspect the repo and propose the base system options. Do not write code yet.
2. **Propose** an architecture and refine this roadmap, then **wait for my approval**.
3. Implement **phase by phase**, with tests, a short README per module, and a "verify on real hardware" checklist at the end of each phase.
4. **Ask me before major design decisions.** Explain trade-offs briefly.
5. Keep the theme layer separate so design changes never touch logic.
6. If something requires jailbreak or exploit internals, stop and tell me instead of writing it.
