# UraxOS progress log

## Done (design phase, in the HTML mockup v4)
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
- Font: Cairo for everything or only Arabic (Space Grotesk/Inter for Latin).
- Logo color: flat `#4FB3F6` or the original saturated gradient.
- Real Steam portrait cover for Hollow Knight (mockup uses a crop of the banner).
- Base distro choice (Phase 0): propose Bazzite / ChimeraOS / Arch / Fedora with trade-offs.

## Next design items
- Gallery stage 2, Library stage 2 (search with on-screen keyboard, per-game settings, add non-Steam app).
- Wi-Fi and Bluetooth screens, Notifications center, Rest mode, on-screen keyboard.
- Security and antivirus design.

## Phase 0 status (cloud session review)
- Mockup v4 reviewed: loads and runs without console errors; boot, profile picker and app launch tested headless.
- Plan fixes: stale "Settings is not designed yet" removed (Settings is designed, see 2.3); PIN wording corrected (4-digit PIN is a convenience lock, not encryption).
- Added proposals awaiting approval: `base-distro-options.md`, `architecture-proposal.md`; added `verify-on-hardware.md`.
- No code written yet, by design (plan section 8: propose first, wait for approval).
