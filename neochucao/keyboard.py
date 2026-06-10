"""
NeoChucao — keyboard.py
Computer keyboard substitute for MIDI input (GarageBand Musical Typing layout).
Mirrors the MidiListener interface: start() / stop(), takes a VoiceManager.

Key events come from the vispy canvas (no pynput / system hooks needed).
The canvas must call on_key_press / on_key_release — wired up in visualizer.start().

Layout:
  White keys:  a  s  d  f  g  h  j  k  l  ;  '
  Notes:       C  D  E  F  G  A  B  C  D  E  F
  Black keys:  w  e     t  y  u     o  p
  Notes:       C# D#    F# G# A#    C# D#

  z / x  — octave down / up
  1–9    — mod wheel in steps (z2 axis)
"""

from __future__ import annotations

from neochucao.latent_map import midi_to_latent, cc_update, adjust_noise_scale, adjust_latent_range
from neochucao import visualizer

KEYBOARD_DEVICE_NAME = "Computer Keyboard"

_WHITE = {'a': 0, 's': 2, 'd': 4, 'f': 5, 'g': 7, 'h': 9, 'j': 11,
          'k': 12, 'l': 14, ';': 16, "'": 17}
_BLACK = {'w': 1, 'e': 3, 't': 6, 'y': 8, 'u': 10, 'o': 13, 'p': 15}
_KEY_TO_OFFSET = {**_WHITE, **_BLACK}
_MOD_KEYS = {str(i): int((i - 1) / 8 * 127) for i in range(1, 10)}


class KeyboardListener:
    """Computer keyboard MIDI substitute driven by vispy canvas key events."""

    def __init__(self, voice_manager):
        self._vm = voice_manager
        self._octave = 4
        self._active: dict[str, int] = {}  # char → MIDI note currently held

    @property
    def device(self) -> str:
        return KEYBOARD_DEVICE_NAME

    def start(self) -> None:
        # Actual key events arrive via on_key_press / on_key_release,
        # which visualizer.start() connects to the canvas after creation.
        print("[keyboard] computer keyboard active (click the visualizer window to focus)")
        print("  White keys : a s d f g h j k l ; '")
        print("  Black keys : w e   t y u   o p")
        print("  Octave     : z (down)  x (up)")
        print("  Mod wheel  : 1–9")
        print("  Noise      : Up / Down arrows  (z3-z15 chaos)")
        print("  Range      : Left / Right arrows  (latent range width)")

    def stop(self) -> None:
        pass  # nothing to tear down; canvas lifecycle handled by vispy

    # ── vispy canvas callbacks ────────────────────────────────────────────────
    # event.text gives the typed character ('a', ';', "'", '1', …)

    def on_key_press(self, event) -> None:
        # Arrow keys have no event.text — handle by key name first.
        key_name = event.key.name if hasattr(event.key, 'name') else ''
        if key_name == 'Up':
            s = adjust_noise_scale(+0.1)
            print(f"[keyboard] noise_scale → {s:.2f}")
            return
        if key_name == 'Down':
            s = adjust_noise_scale(-0.1)
            print(f"[keyboard] noise_scale → {s:.2f}")
            return
        if key_name == 'Right':
            r = adjust_latent_range(+0.1)
            print(f"[keyboard] latent_range → ±{r:.2f}")
            return
        if key_name == 'Left':
            r = adjust_latent_range(-0.1)
            print(f"[keyboard] latent_range → ±{r:.2f}")
            return

        char = event.text
        if not char:
            return

        if char == 'z':
            self._octave = max(1, self._octave - 1)
            print(f"[keyboard] octave → {self._octave}")
            return

        if char == 'x':
            self._octave = min(7, self._octave + 1)
            print(f"[keyboard] octave → {self._octave}")
            return

        if char in _MOD_KEYS:
            update = cc_update(1, _MOD_KEYS[char])
            if update:
                self._vm.cc(update)
                with visualizer._lock:
                    if "z2" in update:
                        visualizer.current_z[2] = update["z2"]
            return

        if char in _KEY_TO_OFFSET and char not in self._active:
            note = (self._octave + 1) * 12 + _KEY_TO_OFFSET[char]
            vel = 90
            self._active[char] = note
            z = midi_to_latent(note, vel)
            self._vm.note_on(note, vel, z)
            visualizer.update_z(z["z0"], z["z1"], z["z2"])

    def on_key_release(self, event) -> None:
        char = event.text
        if char in self._active:
            note = self._active.pop(char)
            self._vm.note_off(note)
