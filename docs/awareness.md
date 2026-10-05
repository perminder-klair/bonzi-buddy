# Desktop awareness

## Sources

The Python standard-library collector uses read-only Hyprland JSON commands and its event socket. Active-window events trigger a debounced refresh; a five-second poll covers geometry changes and reconnection. Geometry is normalized to monitor-local logical coordinates, including monitor scale and rotation. Cursor position is used only to keep avoidance from moving near the pointer. It is never recorded as a history.

System readings use `/proc`, `/sys`, and filesystem capacity: CPU delta, available-memory usage, home filesystem free space, uptime, first reported battery, and network link state. Link state does not establish internet reachability. Missing hardware/readings are unavailable, not fabricated values.

Media uses Quickshell MPRIS (player identity, playback, title, artist). Idle uses the compositor's idle notifier, respecting inhibitors. Omarchy DND uses only `notifications dndState` on the shell IPC endpoint. No notification subscription or body collection is implemented.

## Privacy and focus

Settings persist in `~/.config/bonzi-buddy.ini`. Sensor snapshots are held in memory and are not written to disk. No cloud service, telemetry, activity history, screenshot, clipboard, document content, or keystroke capture is used.

Window awareness exposes class, workspace, monitor, window rectangle, side, and current pointer position. Titles require separate opt-in and are limited to 250 characters. Hyprland's active-window response and event stream can include titles as part of their raw payload; these are discarded before publishing context when title access is off. Media metadata is controlled by the media switch independently of window-title access. `bonzi status` prints enabled readings to the caller, so avoid sharing its output if titles or media metadata are sensitive.

With windows off, focus settings may still query desktop state but publish only availability, fullscreen, and app-match booleans. Disabling all desktop-related switches stops those queries. System/media switches stop their respective collection. Stale collector readings are cleared after 12 seconds; focus checks suppress reactions during a collector outage. Unavailable DND support is shown as unavailable and cannot enforce DND suppression.

## Behavior

Reactions share a cooldown, respect quiet personality/focus/manual sleep, and are suppressed while hidden or editing settings. Suppressed music/idle/app edges are dropped rather than queued for later interruption. Sustained system pressure retries until it can report once, then rearms when pressure clears. Pressure means CPU/RAM at least 90%, home disk below 2 GiB free, or discharging battery at most 15%, continuously observed for 30 seconds.

Dances last 3.6 seconds and alternate three short pose sequences. Playback continuing does not restart a dance. Idle sleep wakes on resumed activity; other sleep rules stay asleep until manually woken. Reduced motion disables dance pose cycling and rotation.

Avoidance chooses a corner only when overlap is reduced. It does not move continuously back toward the saved home position. Moves are separated by 30 seconds and blocked near the pointer, during dragging, and while the panel is open. Dragging sets a new home and pauses avoidance. With no known pointer location, avoidance stays put. Stay-put is the default. Follow-monitor and avoid-window are separate modes.

## Test support

`tests/awareness_runtime.py` copies the app into a temporary directory, supplies synthetic context via `BONZI_CONTEXT_FIXTURE`, and uses `BONZI_SETTINGS_FILE` for isolated preferences. The panel labels fixture mode SIMULATED. Fixture mode does not start live collectors. Tests use a muted instance, stop it afterward, and never change the running user's preferences.
