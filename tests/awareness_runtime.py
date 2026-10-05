#!/usr/bin/env python3
"""Isolated real Quickshell instance; synthetic sensors, temporary preferences, muted."""
import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
env = runpy.run_path(str(ROOT / 'bin/bonzi'))['graphical_environment']()
with tempfile.TemporaryDirectory(prefix='bonzi-qa-') as temp:
    path = Path(temp)
    shutil.copytree(ROOT / 'app', path / 'app')
    (path / 'bin').mkdir()
    shutil.copy(ROOT / 'bin/context.py', path / 'bin/context.py')
    fixture = path / 'fixture.json'
    settings = path / 'settings.ini'
    settings.write_text('[BonziBuddy]\nmuted=true\npersonality=quiet\ncooldownSeconds=10\n')
    env.update(BONZI_CONTEXT_FIXTURE=str(fixture), BONZI_SETTINGS_FILE=str(settings))
    data = {'desktop': {'available': True, 'app': 'TestEditor', 'title': 'Private test title', 'fullscreen': False,
                       'blockedApp': False, 'monitor': {'name': 'test'}, 'side': 'left'},
            'system': {'cpu': 12}, 'media': {'available': True, 'playing': False, 'player': 'Test player'}, 'dnd': False, 'idle': False}
    def sample():
        draft = fixture.with_suffix('.tmp')
        draft.write_text(json.dumps(data))
        draft.replace(fixture)
    sample()
    base = ['quickshell', 'ipc', '-p', str(path / 'app'), 'call', '--', 'bonzi']
    def call(name, *args):
        return subprocess.run(base + [name, *map(str, args)], env=env, capture_output=True, text=True, check=True).stdout.strip()
    def status():
        return json.loads(call('status'))
    def wait(predicate, timeout=8):
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            try:
                s = status()
                if predicate(s):
                    return s
            except (subprocess.CalledProcessError, ValueError):
                pass
            time.sleep(.15)
        raise AssertionError(locals().get('s', 'No IPC response'))
    def launch():
        subprocess.run(['quickshell', '-n', '-d', '-p', str(path / 'app')], env=env, capture_output=True, text=True, check=True, timeout=15)
        return wait(lambda s: not s['context']['stale'])
    try:
        s = launch()
        assert 'title' not in s['context']['desktop']
        assert call('option', 'windowTitles', 'true') == 'ok'
        wait(lambda s: s['context']['desktop'].get('title') == 'Private test title')
        call('option', 'windowsEnabled', 'false')
        wait(lambda s: 'app' not in s['context']['desktop'] and 'title' not in s['context']['desktop'])
        call('option', 'systemEnabled', 'false')
        assert status()['context']['system'] == {}
        call('option', 'mediaEnabled', 'false')
        assert status()['context']['media'] == {}
        call('option', 'windowsEnabled', 'true')
        call('option', 'mediaEnabled', 'true')
        call('option', 'windowTitles', 'false')
        call('option', 'personality', 'chatty')
        call('option', 'cooldownSeconds', '10')
        data['media']['playing'] = True; sample()
        wait(lambda s: s['dancing'])
        wait(lambda s: not s['dancing'], timeout=6)
        assert status()['context']['media']['playing']  # music continues; dance does not
        data['idle'] = True; sample()
        time.sleep(.8)
        assert not status()['sleeping']  # cooldown blocks interruption
        data['desktop']['fullscreen'] = True; sample()
        wait(lambda s: s['focusReason'] == 'Fullscreen' and s['fullscreenHidden'])
        data['desktop']['fullscreen'] = False; data['dnd'] = True; sample()
        wait(lambda s: s['focusReason'] == 'Do Not Disturb')
        data['dnd'] = False; data['desktop']['blockedApp'] = True; sample()
        wait(lambda s: s['focusReason'] == 'Chosen app')
        data['desktop']['blockedApp'] = False; data['idle'] = False; sample()
        wait(lambda s: not s['focusReason'])
        time.sleep(7)
        data['idle'] = True; sample()
        wait(lambda s: s['sleeping'])
        data['idle'] = False; sample()
        wait(lambda s: not s['sleeping'])
        call('option', 'personality', 'quiet')
        data['media']['playing'] = False; sample(); time.sleep(.7)
        data['media']['playing'] = True; sample(); time.sleep(.7)
        assert not status()['dancing']
        for tab in range(4):
            call('panel', tab)
            time.sleep(.2)
        call('capture', '/tmp/bonzi-reactions-qa.png')
        time.sleep(.5)
        call('option', 'movement', 'stay')
        call('quit'); time.sleep(.8)
        s = launch()
        assert s['preferences']['personality'] == 'quiet'
        assert s['preferences']['systemEnabled'] is False
        assert s['preferences']['windowTitles'] is False
        assert s['preferences']['movement'] == 'stay'
        print('PASS: isolated real QML runtime, privacy switches, bounded dance, cooldown, focus gates, idle sleep/wake, quiet mode, panels, cold settings persistence')
    finally:
        try:
            call('quit')
        except subprocess.CalledProcessError:
            pass
