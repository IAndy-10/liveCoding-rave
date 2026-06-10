# NeoChucao — Python + Supriya Architecture

This branch (`python+supriya_architecture`) is an iteration of the [main branch](../../tree/main) project. The original implementation used SuperCollider scripts directly; this version replaces that with a Python-driven architecture, using **Supriya** as the bridge to the SuperCollider audio server (`scsynth`).

> This codebase was developed with LLM assistance — Claude Sonnet 4.6 (Anthropic) was used throughout the design and implementation process.

---

## Stack

| Layer | Technology |
|---|---|
| Audio server | **SuperCollider** (`scsynth`) |
| SC bindings | **Supriya** — Python API for SuperCollider |
| Neural audio | **RAVE** — Real-time Audio Variational autoEncoder |
| SC neural UGen | **nn.ar** — SuperCollider extension for running `.ts` models |
| ML runtime | **PyTorch** (`torch`) |
| MIDI I/O | **mido** + **python-rtmidi** |
| Visualization | **vispy** — real-time 3D OpenGL latent space display |
| UI dialogs | **PyQt5** |
| Audio devices | **sounddevice** — enumerates system audio outputs |
| Numerics | **NumPy** |

---

## How it works

1. Python boots `scsynth` via Supriya and kills any stale process on startup.
2. The RAVE model is loaded into `scsynth` via raw OSC (`/nn_load`) using the `nn.ar` UGen.
3. A `rave_decoder` SynthDef (pre-compiled `.scsyndef`) is loaded; each MIDI note spawns a new node with latent coordinates derived from pitch and velocity.
4. An FX chain (FreeVerb reverb, compiled at runtime by Supriya) sits at the tail of the default group and writes to the hardware output.
5. A real-time 3D visualizer (vispy) renders the current latent position `(z0, z1, z2)` with a fading trail at 60 fps.

---

## Setup

### 1. Dependencies

Create a virtual environment, activate it, and install dependencies:

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

You also need:
- **SuperCollider** installed at `/Applications/SuperCollider.app` (macOS)
- **nn.ar** SuperCollider extension — install it in your SC `Extensions` folder

### 2. RAVE model

Download the birds model from Hugging Face and place it in the `models/` folder, renamed to `birds.ts`:

**[birds_motherbird_b2048_r48000_z16.ts](https://huggingface.co/Intelligent-Instruments-Lab/rave-models/blob/main/birds_motherbird_b2048_r48000_z16.ts)**

```
models/
└── birds.ts    <-- rename the downloaded file to this
```

### 3. Run

Activate the virtual environment (if not already active), then launch:

```bash
source venv/bin/activate
python main.py # or python3 main.py
```

A dialog will prompt you to select your audio output and MIDI input device. Close the visualizer window to quit.
