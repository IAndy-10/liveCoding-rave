"""
NeoChucao — midi.py
MIDI input listener. Reads from a hardware MIDI device and drives the
voice manager and visualizer.

Device selection (in order of priority):
  1. NEOCHUCAO_MIDI_DEVICE env var (substring match)
  2. First available MIDI input port
"""

from __future__ import annotations
import os
import threading

import mido

from neochucao.latent_map import midi_to_latent, cc_update
from neochucao import visualizer


def list_devices() -> list[str]:
    """Return available MIDI input port names."""
    return mido.get_input_names()


def _select_device() -> str:
    ports = list_devices()
    if not ports:
        raise RuntimeError("[midi] No MIDI input devices found.")

    preferred = os.environ.get("NEOCHUCAO_MIDI_DEVICE", "")
    if preferred:
        for p in ports:
            if preferred.lower() in p.lower():
                return p
        print(f"[midi] NEOCHUCAO_MIDI_DEVICE={preferred!r} not found — using first available.")

    return ports[0]


class MidiListener:
    def __init__(self, voice_manager, device_name: str | None = None):
        self._vm = voice_manager
        self._device = device_name or _select_device()
        self._thread: threading.Thread | None = None
        self._stop = threading.Event()

    @property
    def device(self) -> str:
        return self._device

    def start(self) -> None:
        self._thread = threading.Thread(target=self._loop, daemon=True, name="midi-listener")
        self._thread.start()
        print(f"[midi] listening on: {self._device}")

    def stop(self) -> None:
        self._stop.set()

    def _loop(self) -> None:
        with mido.open_input(self._device) as port:
            for msg in port:
                if self._stop.is_set():
                    break

                if msg.type == "note_on" and msg.velocity > 0:
                    z = midi_to_latent(msg.note, msg.velocity)
                    self._vm.note_on(msg.note, msg.velocity, z)
                    visualizer.update_z(z["z0"], z["z1"], z["z2"])

                elif msg.type == "note_off" or (msg.type == "note_on" and msg.velocity == 0):
                    self._vm.note_off(msg.note)

                elif msg.type == "control_change":
                    update = cc_update(msg.control, msg.value)
                    if update:
                        self._vm.cc(update)
                        with visualizer._lock:
                            if "z2" in update:
                                visualizer.current_z[2] = update["z2"]
