"""
NeoChucao — latent_map.py
Maps MIDI input to a 16-dimensional RAVE latent vector.

Active dimensions:
  z0  ← MIDI note       mapped over [NOTE_MIN, NOTE_MAX] → [-_latent_range, +_latent_range]
  z1  ← velocity        mapped over [0, 127]
  z2  ← CC 1 mod wheel  mapped over [0, 127]
  z3–z15 ← Gaussian noise with std-dev _noise_scale (0 = deterministic)

Runtime controls:
  CC 1  → z2 (mod wheel / timbre morph), pushed to all active voices
  CC 2  → _noise_scale (0–3.0, chaos), affects next note-on only
  adjust_noise_scale(delta)  — called by keyboard Up/Down arrows
  adjust_latent_range(delta) — called by keyboard Left/Right arrows

latent_pca in birds.ts is the identity matrix — dimensions are already
sorted by variance explained. No PCA projection needed.
"""

from __future__ import annotations
from pathlib import Path

import numpy as np
import torch

MODELS_DIR = Path(__file__).parent.parent / "models"

# z0 note mapping: the playable keyboard range fills the full latent range.
NOTE_MIN = 36    # MIDI note → -_latent_range  (C2)
NOTE_MAX = 96    # MIDI note → +_latent_range  (C7)

# Mutable runtime parameters (changed via CC or arrow keys)
_latent_range: float = 2.0   # MIDI values map to [-_latent_range, +_latent_range]
_noise_scale:  float = 0.0   # std-dev of Gaussian noise on z3–z15 per note-on

_cc_state: dict[int, int] = {}   # CC number → last raw value (0-127)


def _load_latent_mean() -> np.ndarray:
    model = torch.jit.load(str(MODELS_DIR / "birds.ts"))
    mean = model.latent_mean.detach().numpy().copy()   # shape [16]
    print(f"[latent_map] latent_mean loaded, shape {mean.shape}")
    return mean


# Loaded once at import time from the .ts model
_latent_mean: np.ndarray = _load_latent_mean()

# Session-fixed noise: one unit-normal vector per MIDI note (128 × 13).
# Sampled once at startup so each note has a stable "personality".
# Scaled at runtime by _noise_scale — shape is fixed, intensity is not.
_note_noise: np.ndarray = np.random.normal(0.0, 1.0, size=(128, 13))


def _midi_to_z(value: int, lo: int = 0, hi: int = 127) -> float:
    """Map a MIDI value [lo, hi] linearly to [-_latent_range, +_latent_range]."""
    t = float(np.clip((value - lo) / (hi - lo), 0.0, 1.0))
    return -_latent_range + t * 2.0 * _latent_range


def adjust_noise_scale(delta: float) -> float:
    """Shift _noise_scale by delta, clamped to [0, 3]. Returns new value."""
    global _noise_scale
    _noise_scale = float(np.clip(_noise_scale + delta, 0.0, 3.0))
    return _noise_scale


def adjust_latent_range(delta: float) -> float:
    """Shift _latent_range by delta, clamped to [0.5, 3]. Returns new value."""
    global _latent_range
    _latent_range = float(np.clip(_latent_range + delta, 0.5, 3.0))
    return _latent_range


def midi_to_latent(note: int, velocity: int) -> dict[str, float]:
    """
    Build a full 16-dim latent vector from a note-on event.
    z0–z2 are driven by MIDI; z3–z15 get fresh Gaussian noise each press.
    """
    z = _latent_mean.copy()
    z[0] = _midi_to_z(note, NOTE_MIN, NOTE_MAX)
    z[1] = _midi_to_z(velocity)
    z[2] = _midi_to_z(_cc_state.get(1, 64))
    z[3:] = _note_noise[note] * _noise_scale
    return {f"z{i}": float(v) for i, v in enumerate(z)}


def cc_update(control: int, value: int) -> dict[str, float] | None:
    """
    Update CC state and return a partial latent dict for the changed dimension.
    Returns None if the CC doesn't affect active synth voices.

    CC 1 → z2 (mod wheel, pushed to all active voices)
    CC 2 → _noise_scale (affects next note-on only, not current voices)
    """
    global _noise_scale
    _cc_state[control] = value

    if control == 1:   # mod wheel → z2
        return {"z2": _midi_to_z(value)}

    if control == 2:   # noise knob → _noise_scale (0–3.0)
        _noise_scale = (value / 127.0) * 3.0
        print(f"[latent_map] noise_scale → {_noise_scale:.2f}  (CC2={value})")
        return None

    return None


# ── Smoke test ────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("\n--- midi_to_latent (note range 36-96, no noise) ---")
    for note, vel in [(36, 30), (60, 64), (84, 100), (96, 127)]:
        z = midi_to_latent(note, vel)
        print(f"  note={note:3d} vel={vel:3d}  →  z0={z['z0']:+.3f}  z1={z['z1']:+.3f}  z2={z['z2']:+.3f}")

    print("\n--- midi_to_latent with noise_scale=1.0 ---")
    adjust_noise_scale(1.0)
    for note, vel in [(36, 64), (60, 64), (96, 64)]:
        z = midi_to_latent(note, vel)
        z3_vals = [f"{z[f'z{i}']:+.2f}" for i in range(3, 8)]
        print(f"  note={note:3d}  →  z0={z['z0']:+.3f}  z3–z7: {' '.join(z3_vals)}")

    print("\n--- cc_update ---")
    adjust_noise_scale(-1.0)  # reset
    for val in [0, 64, 127]:
        result = cc_update(1, val)
        print(f"  CC1={val:3d}  →  {result}")
    cc_update(2, 64)   # noise_scale via CC
    cc_update(7, 100)  # unrecognised → None
    print(f"  CC7=100  →  None")

    print("\n--- adjust_latent_range ---")
    r = adjust_latent_range(+1.0)
    print(f"  latent_range → ±{r:.1f}")
    z = midi_to_latent(36, 64)
    print(f"  note=36  →  z0={z['z0']:+.3f}  (expected ±{r:.1f})")
