"""
NeoChucao — keyboard_test.py
Play the instrument from the computer keyboard with 3D latent space visualization.

Layout (GarageBand Musical Typing style):
  White keys:  a  s  d  f  g  h  j  k  l  ;  '
  Notes:       C  D  E  F  G  A  B  C  D  E  F   (C4 = middle C)

  Black keys:  w  e     t  y  u     o  p
  Notes:       C# D#    F# G# A#    C# D#

  z / x  — octave down / up
  q      — quit
  mod wheel: 1–9 keys set z2 in steps (1=min … 9=max)
"""

import queue
import threading
import time
from pynput import keyboard as kb

from neochucao.server import boot, quit as sc_quit, add_synth
from neochucao.latent_map import midi_to_latent, cc_update
from neochucao import visualizer

# ── Layout ────────────────────────────────────────────────────────────────────
WHITE = {'a': 0, 's': 2, 'd': 4, 'f': 5, 'g': 7, 'h': 9, 'j': 11,
         'k': 12, 'l': 14, ';': 16, "'": 17}
BLACK = {'w': 1, 'e': 3, 't': 6, 'y': 8, 'u': 10, 'o': 13, 'p': 15}
KEY_TO_OFFSET = {**WHITE, **BLACK}
MOD_KEYS = {str(i): int((i - 1) / 8 * 127) for i in range(1, 10)}

octave = 4
active: dict[str, int] = {}    # char → MIDI note  (listener thread)
synths: dict[int, object] = {} # note → RawSynth   (audio thread)
cmd_queue: queue.Queue = queue.Queue()


def note_for_key(char: str) -> int:
    return (octave + 1) * 12 + KEY_TO_OFFSET[char]


# ── Keyboard callbacks (listener thread) ─────────────────────────────────────
def on_press(key):
    global octave
    try:
        char = key.char
    except AttributeError:
        return

    if char == 'q':
        cmd_queue.put(('quit', None))
        return False

    if char == 'z':
        octave = max(1, octave - 1)
        print(f"  octave → {octave}")
        return

    if char == 'x':
        octave = min(7, octave + 1)
        print(f"  octave → {octave}")
        return

    if char in MOD_KEYS:
        cmd_queue.put(('cc', MOD_KEYS[char]))
        return

    if char in KEY_TO_OFFSET and char not in active:
        note = note_for_key(char)
        active[char] = note
        cmd_queue.put(('note_on', (note, char)))


def on_release(key):
    try:
        char = key.char
    except AttributeError:
        return
    if char in active:
        note = active.pop(char)
        cmd_queue.put(('note_off', note))


# ── Audio thread ──────────────────────────────────────────────────────────────
def audio_loop():
    while True:
        try:
            cmd, data = cmd_queue.get(timeout=0.01)
        except queue.Empty:
            continue

        if cmd == 'note_on':
            note, char = data
            vel = 90
            z = midi_to_latent(note, vel)
            synth = add_synth("rave_decoder", amp=0.5, **z)
            synths[note] = synth
            visualizer.update_z(z['z0'], z['z1'], z['z2'])
            print(f"  note_on  note={note} z0={z['z0']:+.2f} z1={z['z1']:+.2f} z2={z['z2']:+.2f}")

        elif cmd == 'note_off':
            synth = synths.pop(data, None)
            if synth:
                synth.set(gate=0)
            print(f"  note_off note={data}")

        elif cmd == 'cc':
            update = cc_update(1, data)
            if update:
                for synth in synths.values():
                    synth.set(**update)
                # update z2 in visualizer
                with visualizer._lock:
                    visualizer.current_z[2] = update['z2']
            print(f"  mod wheel → {data}")

        elif cmd == 'quit':
            for synth in synths.values():
                synth.set(gate=0)
            time.sleep(0.5)
            sc_quit()
            break


# ── Entry point ───────────────────────────────────────────────────────────────
boot()
print("\nNeoChucao ready.")
print("  White keys : a s d f g h j k l ; '")
print("  Black keys : w e   t y u   o p")
print("  Octave     : z (down)  x (up)")
print("  Mod wheel  : 1–9")
print("  Quit       : q\n")

# Start keyboard listener
listener = kb.Listener(on_press=on_press, on_release=on_release)
listener.start()

# Start audio loop on background thread
audio_thread = threading.Thread(target=audio_loop, daemon=True)
audio_thread.start()

# Visualizer blocks main thread (OpenGL requirement)
visualizer.start()

# Window closed — clean up
listener.stop()
audio_thread.join(timeout=2)
