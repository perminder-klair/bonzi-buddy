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
| Menu | Buddy controls, awareness/privacy, live status, reaction rules |

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
- The overlay accepts keyboard focus only while the settings panel is open, for editable controls. The CLI also provides actions.

## Awareness and reactions

Right-click Buddy for four tabs: **Buddy**, **Awareness**, **Status**, and **Reactions**.

- Switch windows, media, system health, and idle awareness independently.
- Choose stay put, follow the active monitor, or avoid the active window. Avoidance parks in a less obstructive corner, moves at most once every 30 seconds, and pauses near the pointer or while the panel is open.
- Quiet disables automatic reactions; balanced and chatty default to 120- and 30-second cooldowns. Customize the cooldown in Reactions.
- Focus mode silences automatic reactions and speech during fullscreen, Omarchy DND, or chosen app classes. Fullscreen hiding is separately configurable.
- Inspect current readings in Status. Choose none, dance, wave, speak, or sleep for music starting, becoming idle, changing app, and sustained system pressure.
- Music dances last 3.6 seconds with three alternating pose sequences, then Buddy settles down even while playback continues. Idle-triggered sleep wakes when input resumes.

Window titles are off by default. Notifications and notification-body access are **deferred and disabled**. DND reads only the shell's on/off setting. Processing is local, with no activity history or network requests. See [awareness design and privacy boundaries](docs/awareness.md).

```sh
bonzi panel 2                         # live status (0–3)
bonzi option movement stay
bonzi option personality balanced
bonzi option musicRule dance
bonzi option focusApps "kitty,org.obsproject.Studio"
bonzi option windowTitles false
```

## Development and verification

```sh
python -m unittest discover -s tests -p 'test_*.py'
node tests/reactions.test.cjs
python tests/awareness_runtime.py  # isolated muted instance on the real desktop
python tests/runtime_smoke.py     # optional live speech test; changes/restores running Buddy
```

Use `quickshell -p app` from a desktop terminal for foreground logs. During development, stop/start around substantial changes. The `bonzi` launcher can recover the local graphical environment when invoked from an agent terminal outside the desktop session.

See [implementation and asset notes](docs/implementation.md), [verification record](docs/verification.md), and the [historical research](docs/README.md).

## Scope and limitations

This is an independent desktop remake, not the original Windows program. Artwork is newly generated but depicts the Bonzi character; no claim is made to the original trademark or character rights. Historical site assets in `docs/assets` are research references and are not used by the application.

The animation uses eight key poses, not a complete historical animation library. Speech animation follows process activity rather than phoneme timings. Hit regions approximate the character bounds rather than every transparent pixel. Multi-monitor switching is implemented but needs a multi-monitor test setup. Pointer dragging and click-through should be checked on your desktop; the automated smoke test operates through IPC.
