# Verification — 2026-10-05

## Environment

Verified on this user's running Omarchy/Hyprland Wayland desktop with Quickshell 0.3.1. The selected monitor is HDMI-A-1, with a 2400 × 1350 logical overlay. Flite is installed locally. No dependency installation was required.

## Passed

- QML loaded on the real compositor without final-configuration warnings/errors.
- Generated RGBA sprite sheet loaded and rendered correctly with the menu; app-owned transparent rendering saved in `previews/desktop-menu.png`.
- Real runtime IPC test: hide/show, sleep/wake, lower/upper size limits, reduced motion, position bounds, speech process start, speaking pose, mute cancellation, muted text bubbles, repeated utterance replacement, and both wave frames.
- Cold restart retained mute, size, reduced motion, and normalized position. Original preferences were restored afterward.
- Repeat launch reused/restored the running instance.
- New launcher registration installed in the user's local bin/applications directories. Autostart remains off.
- Final app render captures include the menu and speech bubble. These capture only Bonzi's own scene, not other desktop windows.

## Fixes found during verification

- Explicit settings location replaced missing Qt organization metadata, enabling persistence.
- CLI uses `call -- bonzi ...` so the action named `show` is not mistaken for Quickshell's own IPC subcommand.
- Qt's in-process Flite plugin crashed during reload. Replaced with an isolated Flite process; interruption regression now passes.
- Corrected Flite's floating-point option spelling (`--setf`) so speech actually runs rather than silently returning.

## Not verified automatically

Native desktop UI automation is unavailable in this session. Actual mouse dragging, clicks reaching underlying windows, menu clicks, and audible output quality require a manual check. IPC verifies their shared state/actions and the speech process lifecycle, not physical input or listening. There is only one connected monitor, so switching between monitors and unplugging a monitor remain untested. Other compositors, mixed-DPI setups, fullscreen applications, and suspend/resume are not covered.

The rendered artwork has minor generated edge fringing at high magnification. Eight key poses are available; the build does not reproduce the entire historical animation catalog or the original Sydney voice.
