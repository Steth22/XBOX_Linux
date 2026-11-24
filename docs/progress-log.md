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
