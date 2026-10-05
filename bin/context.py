#!/usr/bin/env python3
"""Read-only, local desktop/system observer. Emits filtered JSON lines, never history."""
import argparse
import json
import os
from pathlib import Path
import select
import shutil
import socket
import subprocess
import time


def run(args):
    try:
        p = subprocess.run(args, capture_output=True, text=True, timeout=1.5)
        return p.stdout.strip() if p.returncode == 0 else None
    except (OSError, subprocess.TimeoutExpired):
        return None


def hypr(name):
    try:
        value = json.loads(run(['hyprctl', '-j', name]) or 'null')
        return value
    except (ValueError, TypeError):
        return None


def desktop_snapshot(window, monitors, windows=True, titles=False, blocked_apps=''):
    if not isinstance(window, dict) or not isinstance(monitors, list):
        return {'available': False, 'fullscreen': False, 'blockedApp': False}
    blocked = {s.strip().casefold() for s in blocked_apps.split(',') if s.strip()}
    result = {'available': True, 'fullscreen': bool(window.get('fullscreen', 0)),
              'blockedApp': window.get('class', '').casefold() in blocked}
    if not windows:
        return result
    result.update(app=window.get('class', ''), workspace=window.get('workspace', {}).get('name', ''), side='none')
    if titles:
        result['title'] = window.get('title', '')[:250]
    monitor = next((m for m in monitors if m.get('id') == window.get('monitor')), None)
    if monitor is None:
        monitor = next((m for m in monitors if m.get('focused')), None)
    if monitor:
        scale = monitor.get('scale', 1) or 1
        width, height = monitor.get('width', 0), monitor.get('height', 0)
        if monitor.get('transform', 0) % 2:
            width, height = height, width
        result['monitor'] = {'name': monitor.get('name', ''), 'width': width / scale, 'height': height / scale}
        at, size = window.get('at'), window.get('size')
        if at and size and width > 0:
            x, y = at[0] - monitor.get('x', 0), at[1] - monitor.get('y', 0)
            result['rect'] = {'x': x, 'y': y, 'width': size[0], 'height': size[1]}
            center = (x + size[0] / 2) / (width / scale)
            result['side'] = 'left' if center < .4 else 'right' if center > .6 else 'center'
    return result


def cpu_percent(previous, current):
    if previous is None or current is None:
        return None
    total = sum(current[:8]) - sum(previous[:8])
    idle = sum(current[3:5]) - sum(previous[3:5])
    return round(max(0, min(100, 100 * (total - idle) / total)), 1) if total > 0 else None


def read_text(path):
    try:
        return Path(path).read_text().strip()
    except OSError:
        return None


def system_snapshot(previous):
    result = {}
    cpu = read_text('/proc/stat')
    current = list(map(int, cpu.splitlines()[0].split()[1:])) if cpu else None
    result['cpu'] = cpu_percent(previous, current)
    memory = read_text('/proc/meminfo')
    if memory:
        fields = {line.split(':')[0]: int(line.split()[1]) for line in memory.splitlines()}
        total = fields.get('MemTotal', 0)
        available = fields.get('MemAvailable', fields.get('MemFree', 0))
        if total:
            result['memory'] = {'percent': round(100 * (total - available) / total, 1), 'usedGiB': round((total - available) / 1048576, 1), 'totalGiB': round(total / 1048576, 1)}
    try:
        disk = shutil.disk_usage(Path.home())
        result['disk'] = {'percent': round(100 * disk.used / disk.total, 1), 'freeGiB': round(disk.free / 1073741824, 1)}
    except OSError:
        result['disk'] = None
    result['uptimeHours'] = round(float((read_text('/proc/uptime') or '0').split()[0]) / 3600, 1)
    batteries = []
    for supply in Path('/sys/class/power_supply').glob('*'):
        if read_text(supply / 'type') == 'Battery':
            capacity = read_text(supply / 'capacity')
            if capacity and capacity.isdigit():
                batteries.append({'percent': int(capacity), 'state': read_text(supply / 'status') or 'Unknown'})
    result['battery'] = batteries[0] if batteries else None
    # Link state, not an assertion of internet reachability. No addresses/SSIDs.
    result['networkLink'] = any(read_text(p / 'operstate') == 'up' for p in Path('/sys/class/net').glob('*') if p.name != 'lo')
    return result, current


def dnd_state():
    shell = Path(os.environ.get('OMARCHY_PATH', '/usr/share/omarchy')) / 'shell'
    value = run(['quickshell', 'ipc', '-p', str(shell), 'call', '--', 'notifications', 'dndState'])
    return True if value == 'on' else False if value == 'off' else None


def connect_events():
    signature = os.environ.get('HYPRLAND_INSTANCE_SIGNATURE')
    if not signature:
        return None
    path = Path(os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}')) / 'hypr' / signature / '.socket2.sock'
    connection = socket.socket(socket.AF_UNIX)
    try:
        connection.settimeout(.2)
        connection.connect(str(path))
        connection.setblocking(False)
        return connection
    except OSError:
        connection.close()
        return None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--windows', action='store_true')
    parser.add_argument('--titles', action='store_true')
    parser.add_argument('--fullscreen', action='store_true')
    parser.add_argument('--blocked-apps', default='')
    parser.add_argument('--system', action='store_true')
    parser.add_argument('--dnd', action='store_true')
    parser.add_argument('--once', action='store_true')
    parser.add_argument('--fixture', help='Explicit local test fixture; no live sensors are read')
    args = parser.parse_args()
    connection, previous, buffer = None, None, b''
    next_poll, next_desktop = 0, 0
    data = {'desktop': {}, 'system': {}, 'dnd': None}
    needs_desktop = args.windows or args.fullscreen or bool(args.blocked_apps)
    while True:
        now = time.monotonic()
        publish = False
        if args.fixture:
            try:
                data = json.loads(Path(args.fixture).read_text())
            except (OSError, ValueError):
                data = {'desktop': {'available': False}, 'system': {}, 'dnd': None, 'fixtureError': True}
            data['simulated'] = True
            publish = True
        else:
            if now >= next_poll:
                if args.system:
                    data['system'], previous = system_snapshot(previous)
                data['dnd'] = dnd_state() if args.dnd else None
                next_poll = now + 5
                next_desktop = min(next_desktop, now)
                if needs_desktop and connection is None:
                    connection = connect_events()
                publish = True
            if needs_desktop and now >= next_desktop:
                data['desktop'] = desktop_snapshot(hypr('activewindow'), hypr('monitors'), args.windows, args.titles, args.blocked_apps)
                if args.windows and data['desktop'].get('monitor'):
                    cursor = hypr('cursorpos')
                    monitors = hypr('monitors') or []
                    monitor = next((m for m in monitors if m.get('name') == data['desktop']['monitor']['name']), {})
                    if isinstance(cursor, dict) and 'x' in cursor and 'y' in cursor:
                        data['desktop']['cursor'] = {'x': cursor['x'] - monitor.get('x', 0), 'y': cursor['y'] - monitor.get('y', 0)}
                next_desktop = float('inf')
                publish = True
        if publish:
            print(json.dumps(dict(data, sampledAt=time.time()), separators=(',', ':')), flush=True)
        if args.once:
            break
        if args.fixture:
            time.sleep(.2)
        elif connection:
            try:
                ready, _, _ = select.select([connection], [], [], .2)
                if ready:
                    chunk = connection.recv(65536)
                    if not chunk:
                        raise ConnectionError('Hyprland disconnected')
                    buffer = (buffer + chunk)[-131072:]
                    lines = buffer.split(b'\n')
                    buffer = lines.pop()
                    relevant = {b'activewindow', b'activewindowv2', b'fullscreen', b'workspace', b'workspacev2', b'focusedmon', b'movewindow', b'movewindowv2', b'openwindow', b'closewindow', b'monitoradded', b'monitorremoved', b'configreloaded', b'changefloatingmode'}
                    if any(line.split(b'>>', 1)[0] in relevant for line in lines):
                        next_desktop = min(next_desktop, time.monotonic() + .15)
            except (OSError, ConnectionError):
                connection.close()
                connection = None
                data['desktop'] = {'available': False}
                print(json.dumps(dict(data, sampledAt=time.time())), flush=True)
        else:
            time.sleep(.2)


if __name__ == '__main__':
    try:
        main()
    except (BrokenPipeError, KeyboardInterrupt):
        pass
