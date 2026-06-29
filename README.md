# liveCoding-rave

Live coding with [RAVE](https://github.com/caillonantoine/RAVE) neural audio models and [ClaudeCollider](https://github.com/jeremyruppel/claude-collider) — where you describe the music and Claude plays it, processed through neural synthesis in real time.

## What is this

RAVE is a neural network that learns the timbre of a sound world (birds, marine mammals, machinery...) and can transform any audio into that sound world in real time.

ClaudeCollider is an MCP server that lets Claude generate and execute SuperCollider code live.

This repo wires them together: you talk to Claude, Claude composes SuperCollider patterns using RAVE as the instrument, and the audio reaches your speakers transformed through neural synthesis in real time.

```
You ──→ Claude ──→ Pbind(\instrument, \rave_birds) ──→ speakers
```

## Prerequisites

- [SuperCollider](https://supercollider.github.io)
- [nn.ar](https://github.com/elgiano/nn.ar) — install the arm64 release into your SC Extensions folder
- [ClaudeCollider](https://github.com/jeremyruppel/claude-collider) — MCP server running and connected to Claude

## Installation

Clone or download this repo. No further installation needed — it's just `.scd` files.

Place your RAVE `.ts` model files in the `models/` folder. The default model is:

| File         | SynthDef       | Character            |
|--------------|----------------|----------------------|
| `birds.ts`   | `\rave_birds`  | organic, airy, avian |

Additional models (`marinemammals.ts`, `wheel.ts`) can be added to `boot.scd` as extra SynthDefs when needed.

Download models from Hugging Face: [Intelligent-Instruments-Lab/rave-models](https://huggingface.co/Intelligent-Instruments-Lab/rave-models/tree/main)

## How to use

### 1. Connect Claude first

Open a conversation with Claude (ClaudeCollider must be connected as an MCP server). Claude will run a short dummy command that triggers a scsynth reboot — this is intentional and happens on an empty server.

### 2. Boot SuperCollider

Open `boot.scd` in the SuperCollider IDE. Select all (`Cmd+A`) and run (`Cmd+Enter`).

Wait for the post window to show:

```
════════════════════════════════════
  liveCoding-rave ready
  Model   : birds
  SynthDef: \rave_birds
  Now talk to Claude.
════════════════════════════════════
```

### 3. Talk to Claude

Start describing what you want:

> "Make a slow dark ambient texture using the birds model"

> "Play a Phrygian melody through birds with long reverb tails"

> "Layer two drones a fifth apart, slow attack, wide stereo"

Claude composes Pbind patterns using `\rave_birds` directly as the instrument — no bus routing needed.

### 4. Keep talking

You can change things mid-session:

> "Make it slower and darker"
> "Add a sparse high layer"
> "Stop everything and start something more rhythmic"

## Signal flow

```
   Pbind(\instrument, \rave_birds, \freq, ...)
         │
         ▼
   SynthDef(\rave_birds)   ← defined on scsynth by boot.scd
   SinOsc → EnvGen → NN(\birds, \forward) → Pan2
         │
         ▼
   ~cc.fx (reverb, delay, distortion...) [optional]
         │
         ▼
      speakers
```

RAVE runs inline inside the SynthDef. The SynthDef lives on scsynth and is visible to both the SC IDE and Claude's sclang process — no bus routing or Ndef needed.

## Standalone examples

The `examples/` folder contains standalone `.scd` files for using RAVE without ClaudeCollider — useful for learning or experimenting directly in SuperCollider:

| File     | Description                                      |
|----------|--------------------------------------------------|
| `1.scd`  | Single RAVE model, switchable, pattern-based     |
| `2.scd`  | Two models in parallel (birds + marinemammals)   |
| `3.scd`  | Microphone input processed through RAVE          |

These run independently — no ClaudeCollider needed.

## Stopping

Say "stop everything" to Claude, or:

```supercollider
~cc.stop;       // stop all patterns safely
// Cmd+. also works but only stops synth nodes — SynthDefs persist
```

Never use `s.freeAll` — it kills ClaudeCollider's limiter chain permanently.
