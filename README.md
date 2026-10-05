# Bonzi Buddy for Omarchy

A small purple desktop companion built with Quickshell and QML. Drag him around, hear a joke, get a fact, or let him nap. The artwork is an original, generated eight-pose sprite sheet inspired by classic BonziBUDDY.

## Run

Requires a Wayland compositor supporting layer-shell (tested on Hyprland), Quickshell, Python 3, Qt Quick Controls, and Flite for local speech. On Omarchy, the package command is `omarchy pkg add quickshell flite` if they are missing.

```sh
./bin/bonzi start
```

Optional launcher registration, using this checkout in place:

```sh
./bin/install
bonzi
```

Registration adds `~/.local/bin/bonzi` and a desktop entry. Keep this checkout at its current path. Nothing enables autostart or edits Hyprland/Omarchy shell configuration.

## Controls

| Action | Result |
| --- | --- |
| Drag with left mouse button | Move Bonzi within the monitor |
| Left-click | Wave and greet; wake from a nap |
| Double-click | Celebrate |
| Right-click | Open/close the control menu |
| Click a speech bubble | Dismiss it and stop speaking |
| Menu | Jokes, facts, mute, sleep, size, reduced motion, monitor, hide, quit |

```sh
bonzi say "Hello from your desktop."
bonzi joke
bonzi fact
bonzi mute
bonzi sleep
bonzi hide
bonzi show
bonzi menu
bonzi status
bonzi quit
```

`bonzi` or `bonzi start` also restores a hidden instance. Running twice does not create a duplicate. Preferences are stored in `~/.config/bonzi-buddy.ini` (or the configured XDG config directory). Hidden/sleeping status is session-only.

## How it works

- QML clips eight poses from one RGBA sprite sheet, then animates blinking, waving, mouth poses, breathing, and celebration. Reduced motion disables pose cycling and breathing.
- A transparent Wayland top-layer surface reserves no tiling space. Only the character's approximate hit area and visible controls receive pointer input.
- Speech runs in a separate local `flite` process. It uses a retro synthetic voice, not the proprietary historical Sydney voice. Audio never requires a server.
- The app has scripted jokes and facts, not an AI conversation backend. It makes no network requests.
- The overlay does not request keyboard focus. The CLI provides keyboard-accessible actions.

## Development and verification

```sh
python tests/runtime_smoke.py  # requires a running Bonzi; speaks briefly and restores settings
```

Use `quickshell -p app` from a desktop terminal for foreground logs. During development, stop/start around substantial changes. The `bonzi` launcher can recover the local graphical environment when invoked from an agent terminal outside the desktop session.

See [implementation and asset notes](docs/implementation.md), [verification record](docs/verification.md), and the [historical research](docs/README.md).

## Scope and limitations

This is an independent desktop remake, not the original Windows program. Artwork is newly generated but depicts the Bonzi character; no claim is made to the original trademark or character rights. Historical site assets in `docs/assets` are research references and are not used by the application.

The animation uses eight key poses, not a complete historical animation library. Speech animation follows process activity rather than phoneme timings. Hit regions approximate the character bounds rather than every transparent pixel. Multi-monitor switching is implemented but needs a multi-monitor test setup. Pointer dragging and click-through should be checked on your desktop; the automated smoke test operates through IPC.
