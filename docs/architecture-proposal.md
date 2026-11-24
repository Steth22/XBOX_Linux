# Architecture proposal (Phase 0, needs owner approval)

Status: Qt 6 / QML approved by the owner. Layout still to be confirmed. Nothing implemented yet.

## Layers
1. Base image (see `base-distro-options.md`).
2. Compositor: a Wayland compositor that hosts Console Mode and PC Mode and handles overlay windows, screenshots and
   recording. Candidates: a wlroots-based compositor we control, or Qt Wayland Compositor.
3. Shell UI: Console Mode and PC Mode screens.
4. Services (separate processes, D-Bus API): network (NetworkManager), Bluetooth (BlueZ), audio (PipeWire), power,
   display, storage, Steam library/art cache, accounts, updates, capture, notifications.
5. Theme layer: colors, fonts, radii, logo as data (JSON/QSS-like), no logic inside.
6. Hardware abstraction layer: each service talks to a `Hal` interface with `mock` (tests, VM, headless) and `pc`
   implementations; `ps4` is added only in the optional last phase.

## Shell UI stack options
| Option | Pros | Cons |
|---|---|---|
| Qt 6 / QML | Native, GPU-accelerated animations, shader effects (blur/glow), good RTL/Arabic text, light enough for weak hardware, mature Wayland support | Mockup (HTML/CSS/JS) must be re-implemented in QML |
| Web UI (Chromium/CEF or WPE WebKit in a kiosk compositor) | Reuses the approved HTML mockup almost directly; fastest to a faithful result | Heavy RAM/CPU; poor fit for PS4-class hardware; blur and animations costly |
| GTK 4 | Native, good RTL | Weaker for custom animated, controller-first UI |

Recommendation: **Qt 6 / QML** for the shell, with services in a systems language (Rust or C++) over D-Bus. If speed to a
first look matters more than weight, a web-based prototype of Phase 1 is acceptable, but production should be QML.
Blur, glow and drift get a "reduced effects" switch per target.

## Repository layout (proposed, created after approval)
- `shell/` Qt/QML shell (console, pc, theme)
- `services/` D-Bus services, each with `mock` and `pc` HAL implementations
- `image/` base image build files, installer, branding
- `tools/` dev scripts (QEMU launch, headless screenshot tests)
- `docs/` plan, decisions, hardware reports

## Cloud-first verification
- Run the shell headless under a nested Wayland compositor or QEMU, take screenshots, and compare against the mockup.
- Controller input is tested through a virtual input device (uinput) in the VM.

## Open questions
- Approve Qt/QML, or prefer a web-based first prototype?
- Approve the layout above?
