# Base system options (Phase 0 proposal, needs owner approval)

Status: DECIDED by the owner: plain Arch (PC target first). Original proposal kept below for reference. Facts below come from general knowledge and must be re-verified against each
project's current documentation before we commit (versions, defaults and maintenance status change).

## Requirements that drive the choice
- Boots on a normal x86-64 UEFI PC; AMD, Intel and NVIDIA GPUs (Wayland).
- Steam + Proton work out of the box; controller support (DualShock 4, Xbox).
- Safe updates with rollback (plan item 19, Settings > Updates > roll back).
- Flatpak for apps, so the base stays clean.
- Easy to build a custom image/ISO with our shell, theme and branding.
- Light enough that a later PS4 port stays possible (optional).

## Options

| Option | Pros | Cons |
|---|---|---|
| Bazzite (Fedora Atomic, image-based) | Gaming-ready (Steam, Proton, drivers incl. NVIDIA variants, controller fixes), atomic updates with rollback, Flatpak-first, we can layer a custom image on top via container-based image builds | Heavy and opinionated; Fedora/ostree workflow to learn; not suited to the weak PS4 hardware; we would be a downstream of their choices |
| ChimeraOS (Arch-based, console-style) | Already console-like (gamescope session, controller-first), immutable root | Smaller community; less flexible for a full PC Mode desktop; tied to their session design |
| Plain Arch | Lightest and most flexible; best base for PS4 community kernels; huge package set | We own all updates, rollback and installer work (btrfs snapshots etc.); more maintenance |
| Plain Fedora (workstation or Silverblue) | Stable, good Wayland/Mesa support, atomic variant available | We must add gaming tweaks ourselves |
| SteamOS-like images | Closest to the target experience | Licensing and portability limits; harder to rebrand |

## Recommendation
1. PC target: start from **Bazzite** (or a Fedora Atomic image built the same way) to get Steam, Proton, GPU drivers and
   rollback for free, and layer UraxOS (shell, theme, services, branding) as a custom image on top.
2. Keep the shell and services distro-agnostic (plain packages + systemd + D-Bus + Flatpak) so an **Arch**-based image can
   be produced later for the optional PS4 port.
3. Prototype everything first in QEMU with the base image to confirm it boots our shell before we commit.

## Questions for the owner
- Do you prefer less work now (Bazzite) or full control and lighter base (Arch)?
- Is NVIDIA hardware in your PC? (affects image variant)
