#!/usr/bin/env python3
"""Exercise the real running companion via IPC; restores preferences on exit."""
import json
from pathlib import Path
import runpy
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
launcher = runpy.run_path(str(ROOT / 'bin/bonzi'))
env = launcher['graphical_environment']()
base = ['quickshell', 'ipc', '-p', str(ROOT / 'app'), 'call', '--', 'bonzi']

def call(name, *args):
    result = subprocess.run(base + [name, *map(str, args)], env=env, capture_output=True, text=True, check=True)
    return result.stdout.strip()

def status():
    return json.loads(call('status'))

def wait_for(predicate, timeout=5):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        state = status()
        if predicate(state):
            return state
        time.sleep(0.1)
    raise AssertionError(state)

original = status()
try:
    call('hide')
    assert status()['hidden']
    call('show')
    assert not status()['hidden']
    call('sleep')
    assert status()['pose'] == 'sleep'
    call('sleep')
    assert not status()['sleeping']
    call('size', 999)
    assert status()['size'] == 288
    call('size', 1)
    assert status()['size'] == 112
    call('motion', 'true')
    assert status()['reducedMotion']
    call('motion', 'false')
    call('move', -1, 2)
    s = status()
    assert s['x'] >= 0 and s['y'] + s['size'] <= s['height']
    if status()['muted']:
        call('mute')
    call('say', 'Hello. This is a local speech test for Bonzi Buddy.')
    wait_for(lambda s: s['speaking'] and s['pose'] == 'speak')
    call('mute')
    wait_for(lambda s: not s['speaking'])
    call('say', 'Muted speech should still appear as text.')
    assert status()['message'] == 'Muted speech should still appear as text.'
    assert not status()['speaking']
    call('mute')
    # Interrupt/replacement regression: the former in-process engine crashed here.
    for text in ('First message.', 'Second message.', 'Last message.'):
        call('say', text)
        time.sleep(0.15)
    wait_for(lambda s: not s['speaking'], timeout=10)
    assert not status()['speechError']
    call('wave')
    frames = set()
    for _ in range(5):
        frames.add(status()['frame'])
        time.sleep(0.18)
    assert {4, 5}.issubset(frames), frames
    print('PASS: hide/show, sleep/wake, size bounds, motion, movement bounds, speech, mute, interruption, wave frames')
finally:
    call('size', original['size'])
    call('motion', str(original['reducedMotion']).lower())
    if status()['muted'] != original['muted']:
        call('mute')
    # Reverse the normalized position transform from the initial status.
    call('move', (original['x'] - 12) / max(1, original['width'] - original['size'] - 24),
         (original['y'] - 48) / max(1, original['height'] - original['size'] - 64))
    call('hide')
    if not original['hidden']:
        call('show')
    if original['sleeping']:
        call('sleep')
