"""
NeoChucao — voice.py
Polyphonic voice manager. One scsynth node per active MIDI note.
"""

from __future__ import annotations
from neochucao.server import add_synth, RawSynth


class Voice:
    def __init__(self, latent_kwargs: dict, amp: float = 0.5):
        self.synth: RawSynth = add_synth("rave_decoder", amp=amp, **latent_kwargs)

    def update(self, latent_kwargs: dict) -> None:
        self.synth.set(**latent_kwargs)

    def release(self) -> None:
        self.synth.set(gate=0)  # triggers ADSR release, synth self-frees via doneAction=2


class VoiceManager:
    def __init__(self):
        self._voices: dict[int, Voice] = {}  # MIDI note → Voice

    def note_on(self, note: int, velocity: int, latent_kwargs: dict) -> None:
        if note in self._voices:
            self._voices[note].release()  # release existing before creating new
        amp = velocity / 127.0 * 0.8
        self._voices[note] = Voice(latent_kwargs, amp=amp)

    def note_off(self, note: int) -> None:
        voice = self._voices.pop(note, None)
        if voice:
            voice.release()

    def cc(self, latent_kwargs: dict) -> None:
        """Push a latent update to all active voices (e.g. from mod wheel)."""
        for voice in self._voices.values():
            voice.update(latent_kwargs)

    def release_all(self) -> None:
        for voice in self._voices.values():
            voice.release()
        self._voices.clear()

    @property
    def active_count(self) -> int:
        return len(self._voices)


# ── Smoke test ────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import time
    from neochucao.server import boot, quit

    srv = boot()
    vm = VoiceManager()

    print("[test] note_on for notes 60, 64, 67 (C-major chord) …")
    vm.note_on(60, 90, {"z0": -0.5, "z1":  0.3})
    vm.note_on(64, 80, {"z0":  0.5, "z1": -0.3})
    vm.note_on(67, 70, {"z0":  1.2, "z1":  0.0})
    print(f"  active voices: {vm.active_count}")
    time.sleep(2)

    print("[test] cc update — sweeping z2 on all voices …")
    for val in [-1.0, -0.5, 0.0, 0.5, 1.0]:
        vm.cc({"z2": val})
        time.sleep(0.3)

    print("[test] note_off for all notes …")
    vm.note_off(60)
    vm.note_off(64)
    vm.note_off(67)
    print(f"  active voices: {vm.active_count}")
    time.sleep(1.5)

    print("[test] rapid note_on / note_off stress test …")
    for i in range(8):
        note = 60 + i * 2
        vm.note_on(note, 100, {"z0": (i - 4) * 0.4})
        time.sleep(0.1)
    time.sleep(0.5)
    vm.release_all()
    time.sleep(1)

    quit()
