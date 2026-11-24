# Project: UraxOS, a Custom Dual-Mode OS Shell (Plan v6)

You are helping me build **UraxOS**, a private/personal Linux-based OS shell and system image. It is a personal project
for me and my circle, not a commercial product.

What changed in v6: the approved Console Mode UX (boot flow, home, MQM, Quick Menu, status corner) is now part of the plan
(section 2.1), the logo is approved, and the font/language rules now cover Arabic. Everything else is carried over from v5.

**Targets**
1. **Primary target: a normal x86-64 PC** (UEFI, installable from USB, optional dual boot).
2. **Optional secondary target: jailbroken PS4 Slim** (firmware 13.52, GoldHEN). This is a "bonus" port, done only after the PC version works.

**Scope rule:** Do NOT write or explain exploit/jailbreak code or how any jailbreak entry point works.
For the PS4 target, assume GoldHEN and BinLoader are already running and use existing community Linux loaders/kernels.

You can talk to me in Arabic or English. Keep code, comments, and docs in English.

**Design sources of truth (in the project pack):**
- `design/console-mockup-v3-latest.html`: interactive Console Mode mockup. Open it in a browser. **Implement it faithfully; ask me before deviating.**
- `references/console-home-structure.jpg` and `references/quick-menu-structure.jpg`: my hand-made structure sketches.
- `assets/logo/logo-final.png`: the approved logo. `assets/logo/logo-sketch.png`: the original sketch.
- Figma file (theme, brand sheet, PC Mode screens): https://www.figma.com/design/goEzwRiSKGL6b9PCyCGDTt
  Note: in Figma the brand sheet, the three boot screens and the PC Mode screens are current. The Console Home, MQM and Quick Menu frames have not been redrawn to match the mockup yet. The HTML mockup wins.

---

## 1. Identity and design

- **Owner name:** Urax. **System name:** UraxOS.
- **Logo (approved):** `assets/logo/logo-final.png`: a bold rounded capital "U" in blue, a sharp four-point sparkle inside the U's counter space, and a tapering diagonal tail crossing the right arm with a clean gap. Treat it as a swappable asset. A clean vector (SVG) version is still needed for the boot screen, icons and installer.
- **Official color:** **Urax Blue `#4FB3F6`**. My sketch used a more saturated blue (`#0A9BFF`); confirm with me before changing the theme.
- **Palette:** Deep Space `#0B1220` (background), Surface `#121B2E` (cards), Mist `#E8F1FB` (text), Muted `#9FB3C8` (secondary text), Border `#2A3A55`.
- **Fonts:** Space Grotesk (Latin headings, wordmark), Inter (Latin body), **Cairo** (Arabic text; the mockup uses it for all UI text). Bundle all three with system fallbacks. Open question for me: Cairo for everything, or Cairo only for Arabic.
- **Language:** the UI must support **Arabic (RTL) and English**. The mockup UI text is Arabic. Layout must mirror correctly for RTL where it makes sense, while the Console home tile row and the Quick Menu stay as in the mockup. Ask me before changing any layout direction.
- **Theme:** dark by default (TV and desk friendly). Colors, fonts, radii and logo live in a swappable theme layer.
- **Design reference (older):** https://claude.ai/artifact/1MKLd8stepFL3Vu3GbHfK6
- Safety, security and antivirus design will be discussed later (see 5.4).

---

## 2. Vision

I boot or launch UraxOS and get one system with two modes.

**Console Mode**: behaves like a game console, with my own design.
- Fullscreen, controller-first launcher
- Power-on and boot flow, profile welcome (see 2.1)
- Home with horizontal app tiles (see 2.1)
- MQM, the quick radial menu opened by holding L2 (see 2.1)
- Quick Menu, a glass panel opened from anywhere with the Home button (see 2.1)
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

Switching between modes is fast and needs no reboot. The home screen has a "PC Mode" tile for this.

### 2.1 Console Mode UX spec (from the approved mockup)

All sizes below are for a 1920x1080 stage and should scale to the real screen.

**Boot flow**
1. Off state: black screen with a round glowing power button and the caption "press to power on". Enter/Space/click starts it.
2. Startup chime (short rising four-note tone).
3. Boot screen: the **approved logo mark** (Urax Blue with a soft blue glow, fading and scaling in), the "UraxOS" wordmark under it with a light sweep, a progress bar, and status lines that change as it progresses (hardware check, network and Bluetooth, game library, interface). Then "Ready". The logo stays the same on every boot screen and on the installer.
4. Profile welcome: round avatar with the profile initial and "Welcome, <profile name>". Then it fades into Home.
5. Shutdown and Restart (from the Quick Menu) return to the off state; Restart powers on again automatically.

**Home**
- Top-left: clock (24h). Top-right: status corner (see below). Bottom-left: controller hints.
- A translucent blurred band across the middle holds a horizontal row of app tiles. Order in the mockup: Gallery, a Steam game (Hollow Knight as the example), Brave, Steam, App Library, PC Mode.
- Tile: rounded square (about 220x208) with the app icon on a gradient. The focused tile grows (about 375x355), becomes fully bright, gets a 5 px Urax Blue ring and a soft blue glow. Unfocused tiles are dimmed.
- Moving focus scrolls the row smoothly so the focused tile stays at the left third.
- Under the focused tile: the app name (large, bold) and the source line (for example "From Steam"). On focus change the old text slides out to the left and the new text slides in from the left, name first, then the source line.
- The full-screen background changes per focused app with a cross-fade and a slow drift. For a Steam game, the background uses that game's own Steam art from the local Steam library; otherwise a themed gradient.
- Launching an app: a circular reveal from the center, showing the app icon, name and a spinner, then the app. A "Home" action returns to Home.
- Toasts: a small pill near the bottom center for short feedback ("Screenshot saved to Gallery", "Wi-Fi: on").
- Screenshot feedback: a quick white flash plus a toast.

**Status corner (top-right)**
- Wi-Fi icon, Bluetooth icon (dimmed when off), a yellow pulsing charging bolt (only while charging), battery percentage, and a battery icon whose fill follows the percentage.

**MQM (hold L2 / LT)**
- A glass half-circle hangs from the top edge of the screen, partly off-screen. While L2 is held it grows to full size and the screen dims slightly. Releasing L2 closes it. On touch or mouse, tapping the half-circle keeps it open until tapped outside.
- Five options sit on its lower edge at fixed angles. They are picked with the **right stick** (the direction picks the nearest option; a dead zone avoids accidental picks). Only the selected icon grows (about 1.45x) and its name shows below. **No pointer line.** Confirm with A.
- Options: Settings, Wi-Fi, Bluetooth, Library, and a fifth unnamed slot with an X icon that does nothing (reserved).
- Wi-Fi and Bluetooth toggle immediately; Library jumps to the App Library tile; Settings is not designed yet.
- Mouse: moving the mouse aims the same way.

**Quick Menu (Home button on the controller; `H` on keyboard)**
- A glass panel slides in from the left and covers about half of the screen (about 985 px wide), with a blurred, darkened background.
- Title "Quick Menu". Two columns:
  - Left column (4 rows): the **current app** (its icon and name), Sound, Network and devices, Power.
  - Right column: the sub-options of the selected row (PS4-style).
- Sub-options in the mockup:
  - Current app: Continue, Screenshot, Close app.
  - Sound: Volume up, Volume down, Mute.
  - Network and devices: Wi-Fi on/off, Bluetooth on/off, Connected devices (controller, keyboard, headset).
  - Power: Rest mode (not designed yet), Restart, Shut down.
- Navigation: Up/Down moves inside a column; Right moves into the sub-options, Left goes back to the left column; A confirms; B goes back and then closes. The focused row is solid Urax Blue with dark text; the selected row in the unfocused column is a soft blue highlight.
- Quick Apps (5.5, item 29) will live inside the Quick Menu later; where they go is still to be decided.

**Controller map (mockup)**
- D-pad or left stick: move focus. A: confirm. B: back. Home: Quick Menu. L2 (hold): MQM. Right stick: pick an MQM option.
- Keyboard equivalents: arrows, Enter/Space, Esc, `H` or Tab, `L` or `Q` (hold).

**Other behavior**
- Respect "reduced motion": switch off the drift, pulses and long transitions.
- The mockup rotates to fit a portrait phone; that is for previewing only and is not a product feature.

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
- The blur, glow and drift effects in 2.1 are the heaviest parts of the UI: build them so they can be reduced or switched off per target.

---

## 5. Features

### 5.1 Core (required for a daily-usable system)
1. **Networking UI**: Wi-Fi and Ethernet scan, connect with password (on-screen keyboard), manual and automatic connection, saved networks, smooth switching. Build on NetworkManager over D-Bus.
2. **Bluetooth UI**: pair, connect, forget keyboards, mice, controllers and headphones. Build on BlueZ.
3. **Audio**: HDMI/speakers, Bluetooth headphones (A2DP, mic profile if possible), volume control, via PipeWire.
4. **Display settings**: resolution, refresh rate, scaling, HDR if feasible.
5. **On-screen keyboard** usable with a controller (Arabic and English layouts).
6. **Power**: shutdown, restart, rest mode, screensaver/suspend (suspend only where reliable; on PS4 use a screensaver instead).
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
10. **Steam integration**: detect Steam and installed games (parse `libraryfolders.vdf` and `appmanifest_*.acf`), show them as tiles in Console Mode (with their Steam art as the Home background, see 2.1), launch through Steam, support Proton.
11. **Game streaming**: Moonlight and Steam Link.
12. **Emulators**: RetroArch as a section in Console Mode.
13. **Media apps**: local video player, YouTube/Netflix via browser.
14. **Performance modes**: power saver / balanced / max, plus an overlay with FPS, temperature and RAM.
15. **Controller remapping** per game.
16. **Remote control** from my phone, plus photo and file upload from the phone.
17. **User accounts** with parental controls and play-time limits. The profile name and initial shown in the boot welcome come from here.
18. **Backup and restore** for settings and game saves.
19. **Signed OTA updates** with rollback.

### 5.4 Later (design extension points now, implement later)
20. App store (Flatpak backend).
21. Switchable themes and animated wallpapers.
22. Advanced notification center and Discord voice chat inside Console Mode.
23. Security: sandboxed apps with a permission model, nftables firewall, optional ClamAV scanning.
24. Boot animation using the final logo (the mockup's wordmark sweep is the starting point).

### 5.5 Capture, overlay and resume features
25. **Recorder**: screen recording via PipeWire, GPU encoding (VAAPI), Share button shortcut. Quality is configurable.
26. **Replay (instant replay)**: rolling buffer of the last gameplay.
    - Options: Off / 5 / 10 / 15 minutes. Maximum for v1: 15 minutes.
    - Buffer location and quality are configurable.
    - Raising the limit (30 / 60 minutes) is a future item, evaluated after the full version and measured on the PS4 target.
27. **Overlay**: floating mini windows (YouTube, Discord) above games, handled by our compositor. Must stay lightweight.
28. **Notifications**: Discord, YouTube (browser) and other apps are captured and shown in our own notification center.
29. **Quick Apps**: small apps inside the Quick Menu (volume, gallery, a web link in a small window). Placement inside the Quick Menu is still to be designed.
30. **Quick Resume**: research track, no promise yet.
    - Try system hibernate on PC first.
    - Fallback: restore the last game and last save, not the exact moment.
    - CRIU is experimental and not planned for v1.

---

## 6. Technical constraints

- **Stack:** Wayland compositor plus Qt/QML or similar. Propose the stack and justify it before using it. It must stay light enough for a PS4-class machine so the PS4 port remains possible. It must be able to do the blur, glow and animations in 2.1 with a reduced mode.
- **Separation:** hardware-specific code isolated behind interfaces; the shell runs in QEMU/VM.
- **Safety:** installers and disk tools must be conservative, confirm destructive actions, and never touch disks the user did not select.
- **Logging:** write logs to a user-visible folder for debugging.

---

## 7. Roadmap

- **Phase 0 (PC):** dev environment, base image choice (with my approval), VM setup, project structure, hardware abstraction layer with mocks.
- **Phase 1 (PC):** minimal shell, controller navigation, theme layer using the UraxOS palette, fonts and approved logo, Arabic/RTL text rendering, boot flow and profile welcome (mocked).
- **Phase 2 (PC):** Console Mode in full, matching the mockup: Home tiles, per-app backgrounds, status corner, MQM, Quick Menu, toasts, notifications center base, gallery, screenshots, Recorder, Quick Apps, game library with mocked games.
- **Phase 3 (PC):** PC Mode (desktop, file explorer, task manager, browsers via Flatpak).
- **Phase 4 (PC):** Steam library integration, settings app, networking and Bluetooth UI, audio, display.
- **Phase 5 (PC):** installer ISO, live USB, dual boot, GPU support matrix, first real-PC tests.
- **Phase 6 (PC):** performance modes, streaming, emulators, Replay (15 min max), Overlay, Discord/YouTube notifications, verify the 5.2 compatibility table.
- **Phase 7:** updates with rollback, backups, users, security, final boot animation with the vector logo.
- **Phase 8 (optional, PS4):** hardware sanity check with community Linux builds on my console (display, input, Ethernet, Wi-Fi/Bluetooth, memory size), record results in `docs/hardware-report.md`, then add a `ps4` target and a launcher app.
- **Separate research task:** Quick Resume (see 5.5, item 30).

### Design items still open (not for Claude Code to invent)
1. Screens not designed yet: Settings, Wi-Fi, Bluetooth, Gallery, App Library, Notifications center, Rest mode.
2. PC Mode screens exist in Figma (desktop, Start menu, File Explorer, Task Manager) and need my review.
3. Vector (SVG) version of the approved logo, and its wiring into the boot screen and icons.
4. Font decision (Cairo for everything or only for Arabic).
5. Security and antivirus design (to be discussed later).

---

## 8. How to work

1. **First**, inspect the repo and propose the base system options. Do not write code yet.
2. **Propose** an architecture and refine this roadmap, then **wait for my approval**.
3. Implement **phase by phase**, with tests, a short README per module, and a "verify on real hardware" checklist at the end of each phase.
4. **Ask me before major design decisions.** Explain trade-offs briefly.
5. Keep the theme layer separate so design changes never touch logic.
6. Treat `design/console-mockup-v3-latest.html` as the UX source of truth for Console Mode; if the real shell cannot match something in it, tell me and propose options.
7. If something requires jailbreak or exploit internals, stop and tell me instead of writing it.
