# UraxOS progress log

## Done (design phase, in the HTML mockup v5)
- Approved logo (vector trace in `assets/logo/logo-vector-traced.svg`; a clean hand-made SVG is still wanted).
- Boot flow: power button, chime, boot screen (logo outline glow, then fill, text "Booting" only), profile picker (users, Guest, New user, optional PIN), welcome, Home.
- Home: tile band, per-app backgrounds, Steam-art backgrounds with slow left-right pan, status corner, toasts.
- MQM (hold L2, or tap on touch): Home screen only; gear icon for Settings.
- Quick Menu: top row "Return to Home"; sub-options hidden until chosen, slide transition, explicit Back row; Power includes "Switch user".
- Settings: 14 categories, connected services (Steam, Twitch, YouTube, Discord, Xbox) with a simulated device-code flow.
- Gallery stage 1 (grid, tabs, albums per game, viewer, info, favorites).
- App Library stage 1 (grid, tabs, sort, game page, download/update simulation, pin to Home).

## Decided
- Steam provides game art (icon, background) by app id; non-Steam apps use local icon + gradient.
- Figma is dropped; the HTML mockup is the source of truth.
- PC first; PS4 port optional and last.
- Cloud-first development; the owner tests on a PC later (VM image first, then live USB).

## Open questions for the owner
- Font: Urax Display for Latin headings, Cairo for Arabic (proposed; owner review pending).
- Logo color: flat `#4FB3F6` or the original saturated gradient.
- Real Steam portrait cover for Hollow Knight (mockup uses a crop of the banner).

## Next design items
- Gallery stage 2, Library stage 2 (search with on-screen keyboard, per-game settings, add non-Steam app).
- Wi-Fi and Bluetooth screens, Notifications center, Rest mode, on-screen keyboard.
- Security and antivirus design.

## Phase 0 status (cloud session review)
- Mockup v4 reviewed: loads and runs without console errors; boot, profile picker and app launch tested headless.
- Plan fixes: stale "Settings is not designed yet" removed (Settings is designed, see 2.3); PIN wording corrected (4-digit PIN is a convenience lock, not encryption).
- Added proposals awaiting approval: `base-distro-options.md`, `architecture-proposal.md`; added `verify-on-hardware.md`.
- No code written yet, by design (plan section 8: propose first, wait for approval).

## Decisions (owner, latest)
- Base distro: Arch (plain). GPU: the owner has a discrete card (taken as NVIDIA; confirm the exact model).
- Shell stack: Qt 6 / QML (recommendation accepted).
- Custom brand font requested; built as Urax Display (see below).

## v5 mockup changes (design/console-mockup-v5-latest.html; v4 kept in design/archive)
- Fixed: Gallery, Library and Settings were mostly static; added features and menus (no large new screens).
- Gallery: viewer options menu (wallpaper, share, USB, delete with confirm), storage bar.
- Library: per-game settings panel (performance, resolution, FPS cap, compatibility layer).
- Settings: footer hints, live effects (theme color, 24h clock, font size, contrast, reduced motion), new rows and a restore-defaults action.
- Headings use the new Urax Display font (embedded as WOFF2).
- Key `O` / controller Y opens the contextual options.
- These are proposals; the owner has not given the final design decision, so each can be changed or reverted.

## Font
- `assets/fonts/UraxDisplay-Bold.ttf/.woff2`, built by `python3 tools/build_font.py` (needs fonttools, shapely, brotli). Latin caps, digits, punctuation; sparkle period. No Arabic glyphs (Cairo fallback).
- Open: a custom Arabic companion face; owner review of letter shapes.

## Notifications (v5 mockup)
- Flush left card with attached typing box, sharp corners; UB selects, L2 dismisses, cross = reply, triangle = floating video. See plan 2.8.
- Open: notification center, stacking.
- On-screen keyboard redone in PS4/PS5 style (compact floating panel, L2 delete, R2 space, L1/R1 cursor, real caret). Button mapping from memory, needs verification against a real PS4/PS5. See plan 2.9.

## Virtual controller (v5 mockup)
- On-screen remote that drives the real gamepad code path, for testing by touch. Plan 2.10.

## Quick Menu and Library updates (v5)
- Quick Menu: new Notifications list (icons, two-line rows, time, new-dot, DND, clear all); Return to Home only when not on Home.
- Library: L1/R1 switch tabs.

## English-first pass (v5)
- Whole mockup UI translated to English; Arabic later as its own pass.
- MQM: L2 glyph only when closed; release L2 runs the aimed option.
- Screen touch/mouse fully blocked while the virtual controller is shown.

## Console Mode design complete (v5)
- Added Wi-Fi and Bluetooth screens, service pages, Rest mode, Gallery stage 2, Library stage 2, shared dialog component. Plan 2.12.
- Next: PC Mode design.

## PC Mode designed (v5 mockup)
- Full desktop with Windows-style features: window manager, taskbar, Start, quick settings, notification center, task view + virtual desktops, Alt+Tab, lock screen, Files, Task Manager, Settings, Terminal, Text Editor, Photos, Calculator, Brave, Store, Steam, Discord. Controller cursor for testing. Plan 2.13.
- Next: owner review of PC Mode, then Phase 0 build work.

## Windows simulator 0.5 (sim/)
- Electron app with installer, saved state, real hardware info, controller and keyboard/mouse verified end to end (40 controller/keyboard checks + 16 mouse checks on Electron). Test tools removed. Fixed: desktop icons were blocked by the window layer; Start search now takes typing immediately.
- Owner to try on Windows 11 with a PS4 controller over Bluetooth.

## 2026-11-24: Real-use test target
- Owner decision: real-hardware test device is a **PS4 Slim** (CUH-2xxx, Belize southbridge), with GoldHEN already running.
- Order: finish the VirtualBox alpha image first, then build a PS4 Slim variant from the same rootfs (PS4-patched kernel + initramfs, loaded by the GoldHEN Linux loader).
- Storage: owner chose the **internal disk** (riskier than USB; back up saves first, and the install guide must warn about this).

## 2026-11-24: Phases 0-2 alpha (real Linux, VirtualBox)
- `os/build.sh` builds a UEFI GPT disk from the Arch bootstrap: plain Arch, linux kernel, systemd-boot, greetd autologin (user `urax`, password `urax`) into Plasma 6 Wayland.
- Console Mode = `urax-shell` (Qt 6 WebEngine, fullscreen) showing the v5 design, autostarted in the Plasma session. `os/shell/bridge.*` + `bridge.js` expose real system calls; `host.js` wires the design to them.
- Wired and verified in QEMU: auto power-on, real app list (desktop apps, flatpak, Steam library) on Home and in App Library, real launch (shell hides, comes back when the app exits), PC Mode = hide shell and show the real Plasma desktop (Urax wallpaper, "Console Mode" icon brings the shell back), volume (wpctl), Wi-Fi/Bluetooth radios and Wi-Fi join (nmcli), screenshots into ~/Pictures/Screenshots shown in Gallery, Shut down/Restart = real poweroff/reboot.
- VMs: Chromium GPU compositing gives a black window, so the shell switches to software rendering when it detects a VM (DMI vendor); real hardware keeps the GPU.
- Delivery: `os/vbox/make-ova.sh` makes a VMDK + "Create UraxOS VM.cmd" (VBoxManage: EFI, 6 GB, 4 CPUs, VMSVGA, USB filter for Sony controllers).

### Verify on real hardware (VirtualBox on the owner's PC)
- [ ] VM boots to Console Mode by itself.
- [ ] PS4 controller over USB cable works in the console (Gamepad API).
- [ ] Steam installs and opens from the Steam tile; a game launches and the console returns after quitting.
- [ ] PC Mode and back (Console Mode icon).
- [ ] Sound, network, Shut down/Restart.

## 2026-11-24: PC Mode is our design (owner decision)
- Owner rejected the stock Plasma desktop ("I want ours"). Decision: our design 100%, Plasma stays hidden as the window engine only.
- `urax-shell --desktop` runs the v5 PC Mode as two layer-shell surfaces: `desk` (wallpaper + icons, background layer) and `bar` (taskbar, Start, flyouts, dialogs; top layer with an input mask so only visible parts take clicks, and an exclusive zone for the taskbar). `plasmashell` is masked.
- `os/shell/windows.*` reads real KWin windows (org_kde_plasma_window_management) for the taskbar: running/active state, click to focus/minimize, close from the context menu, Show desktop.
- Design apps map to real apps for now: Files=Dolphin, Browser=Firefox, Terminal=Konsole, Settings=System Settings, Task Manager=System Monitor, Text Editor=KWrite, Photos=Gwenview. App windows use the "Urax" color scheme. Replacing these with our own apps is a later step.
- Bar hides while Console Mode is on screen; the desktop hands keyboard focus back to Console Mode when it returns.
- Verified in QEMU: boot to Console Mode, keyboard nav, PC Mode tile -> our desktop, taskbar click opens Files, Start opens Terminal, taskbar tracks windows, Console Mode icon returns to the console with keyboard working.
