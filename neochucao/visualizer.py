"""
NeoChucao — visualizer.py
Real-time 3D OpenGL visualization of the RAVE latent position.

Renders at 60 fps:
  - A glowing point at the current (z0, z1, z2) position
  - A fading trail of the last 120 positions (2 seconds)
  - Point size and colour encode z1 (energy/velocity)

Must run on the main thread (OpenGL requirement).
Other threads write to `current_z` to update the position.
"""

from __future__ import annotations
import threading
from collections import deque

import numpy as np
from vispy import app, scene
from vispy.scene import visuals

# ── Shared state (written by MIDI/keyboard thread, read by main thread) ───────
current_z = np.zeros(3, dtype=np.float32)   # [z0, z1, z2]
_lock = threading.Lock()

TRAIL_LEN = 120   # 2 seconds at 60 fps


def update_z(z0: float, z1: float, z2: float) -> None:
    """Called from the MIDI/keyboard thread on each note_on or CC update."""
    with _lock:
        current_z[0] = z0
        current_z[1] = z1
        current_z[2] = z2


def _z1_to_color(z1: float) -> np.ndarray:
    """Map z1 [-2, 2] to a colour: cold blue (low) → hot white (high)."""
    t = np.clip((z1 + 2.0) / 4.0, 0.0, 1.0)
    return np.array([t * 0.6 + 0.4, t * 0.4 + 0.2, 1.0 - t * 0.5, 1.0], dtype=np.float32)


def start(key_listener=None) -> None:
    """
    Launch the vispy window. Blocks the calling thread (must be main thread).
    Call after starting MIDI/keyboard listener threads.

    key_listener: optional KeyboardListener — its on_key_press / on_key_release
                  callbacks are connected to the canvas so no system hooks are needed.
    """
    canvas = scene.SceneCanvas(
        title="NeoChucao — Latent Space",
        size=(800, 700),
        bgcolor="#0a0a0f",
        show=True,
    )
    view = canvas.central_widget.add_view()
    view.camera = scene.cameras.TurntableCamera(
        fov=45, distance=8.0, elevation=20, azimuth=30
    )

    # ── Axis lines ────────────────────────────────────────────────────────────
    axis_len = 2.5
    for vec, color, label, label_pos in [
        ([axis_len, 0, 0], "#ff4444", "z0", [axis_len + 0.2, 0, 0]),
        ([0, axis_len, 0], "#44ff44", "z1", [0, axis_len + 0.2, 0]),
        ([0, 0, axis_len], "#4488ff", "z2", [0, 0, axis_len + 0.2]),
    ]:
        visuals.Line(
            pos=np.array([[0, 0, 0], vec], dtype=np.float32),
            color=color, width=1.5, parent=view.scene
        )
        visuals.Text(
            label, pos=label_pos, color=color,
            font_size=10, parent=view.scene
        )

    # ── Trail ─────────────────────────────────────────────────────────────────
    trail: deque = deque(maxlen=TRAIL_LEN)
    trail_line = visuals.Line(
        pos=np.zeros((2, 3), dtype=np.float32),
        color=np.zeros((2, 4), dtype=np.float32),
        width=2, method="gl", connect="strip",
        parent=view.scene
    )

    # ── Current position marker ───────────────────────────────────────────────
    marker = visuals.Markers(parent=view.scene)
    marker.set_data(
        np.zeros((1, 3), dtype=np.float32),
        face_color=np.array([[0.4, 0.6, 1.0, 1.0]], dtype=np.float32),
        size=14, edge_width=0,
    )

    # ── Keyboard listener (optional) ──────────────────────────────────────────
    if key_listener is not None:
        canvas.events.key_press.connect(key_listener.on_key_press)
        canvas.events.key_release.connect(key_listener.on_key_release)

    # ── 60 fps timer ──────────────────────────────────────────────────────────
    def on_timer(_event):
        with _lock:
            pos = current_z.copy()

        trail.append(pos.copy())

        # Update marker
        marker.set_data(
            pos.reshape(1, 3),
            face_color=_z1_to_color(pos[1]).reshape(1, 4),
            size=12 + pos[1] * 3,
            edge_width=0,
        )

        # Update trail with alpha fade
        if len(trail) > 1:
            pts = np.array(trail, dtype=np.float32)
            n = len(pts)
            alphas = np.linspace(0.05, 0.7, n).astype(np.float32)
            colors = np.zeros((n, 4), dtype=np.float32)
            colors[:, 0] = 0.3 + alphas * 0.4   # R
            colors[:, 1] = 0.5 + alphas * 0.3   # G
            colors[:, 2] = 1.0                   # B
            colors[:, 3] = alphas
            trail_line.set_data(pos=pts, color=colors)

        canvas.update()

    timer = app.Timer(interval=1 / 60, connect=on_timer, start=True)  # noqa: F841

    app.run()


# ── Standalone test ───────────────────────────────────────────────────────────
if __name__ == "__main__":
    import threading, time, math

    def _animate():
        t = 0.0
        while True:
            update_z(
                z0=math.sin(t * 0.7) * 1.8,
                z1=math.sin(t * 1.1) * 1.5,
                z2=math.cos(t * 0.5) * 1.2,
            )
            time.sleep(1 / 60)
            t += 1 / 60

    threading.Thread(target=_animate, daemon=True).start()
    start()
