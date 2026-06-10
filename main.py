"""
NeoChucao — main.py
Entry point. Shows device selection dialog, then boots the server,
starts the MIDI listener, and runs the visualizer.
"""

import sys

from neochucao.ui import show_launch_dialog
from neochucao import server, visualizer
from neochucao.voice import VoiceManager
from neochucao.midi import MidiListener
from neochucao.keyboard import KeyboardListener, KEYBOARD_DEVICE_NAME

# ── Device selection ──────────────────────────────────────────────────────────
result = show_launch_dialog()
if result is None:
    sys.exit(0)

output_device, midi_device = result

# ── Boot ──────────────────────────────────────────────────────────────────────
server.boot(output_device=output_device)

vm = VoiceManager()
if midi_device == KEYBOARD_DEVICE_NAME:
    listener = KeyboardListener(vm)
else:
    listener = MidiListener(vm, device_name=midi_device)
listener.start()

print(f"[main] audio out : {output_device}")
print(f"[main] MIDI in   : {midi_device}")

# ── Visualizer (blocks main thread until window is closed) ────────────────────
print("[main] opening visualizer — close the window to quit")
kb = listener if isinstance(listener, KeyboardListener) else None
visualizer.start(key_listener=kb)

# ── Teardown ──────────────────────────────────────────────────────────────────
print("[main] shutting down …")
listener.stop()
vm.release_all()
server.quit()
