# Omarchy desktop companion

The approved direction is a standalone Quickshell/QML desktop pet. The first build uses an original AI-generated transparent eight-pose sprite sheet, a Wayland top-layer surface, explicit pointer input regions, local Flite speech in a separate process, and persistent size/mute/motion/position settings. It has no network backend or account requirement.

## Animation asset

`app/assets/bonzi-sprites.png` was generated on 2026-10-05 with the built-in image tool, specifically for this project. It is new Bonzi-inspired artwork, not an extraction from the historical Windows binary. The source is preserved as generated: 1774 × 887 RGBA, four columns and two rows. QML clips proportional cells, so the fractional cell width does not require destructive image processing.

Frames: neutral, blink, speaking, expressive speaking, wave A, wave B, sleep, celebrate. Runtime animation adds breathing, a brief periodic blink, alternating waves, and mouth-pose cycling while the speech subprocess is running. This is stylized speech animation, not phoneme-level lip synchronization. Reduced motion stops cycling and breathing.

## Desktop behavior

A transparent full-screen layer has pointer regions only for the character's approximate bounds and visible controls. The blank desktop area passes clicks through. The layer reserves no tiling space and does not request keyboard focus. Dragging changes normalized coordinates. Position is clamped to the selected monitor; a menu action moves between monitors. Monitor disconnection falls back to an available screen.

Keyboard interaction is provided through the `bonzi` CLI/IPC; the pointer menu intentionally does not take focus from the active application. Hide is reversible through `bonzi show`. Startup is manual by default. Nothing modifies the packaged Omarchy shell or Hyprland configuration.

## Verification targets

Load without QML errors on the installed Quickshell; inspect rendered character/menu/bubbles; exercise speech, hide/show, sleep/wake, mute, resize, movement, and shutdown through IPC; verify persistent preferences after a cold restart. Manual dragging/click-through and physical audio listening need human confirmation when native UI automation is unavailable.

## Speech isolation

The installed Qt Flite plugin crashed during development reload inside `libflite`. The final application does not load QtTextToSpeech. `Speech.qml` starts the installed `flite` executable with a structured argument list, cancels it on mute/hide/quit, and replaces interrupted utterances without sharing voice-library state with the UI. No shell evaluates spoken text.
