# liveCoding-rave

Live coding with [RAVE](https://github.com/caillonantoine/RAVE) neural audio models and [ClaudeCollider](https://github.com/jeremyruppel/claude-collider) — where you describe the music and Claude plays it, processed through neural synthesis in real time.

## What is this

RAVE is a neural network that learns the timbre of a sound world (birds, marine mammals, machinery...) and can transform any audio into that sound world in real time.

ClaudeCollider is an MCP server that lets Claude generate and execute SuperCollider code live.

This repo wires them together: you talk to Claude, Claude composes patterns using SuperCollider synths, and the audio passes through RAVE models before reaching your speakers.

```
You ──→ Claude ──→ SuperCollider patterns ──→ RAVE model ──→ speakers
```

## Prerequisites

- [SuperCollider](https://supercollider.github.io)
- [nn.ar](https://github.com/elgiano/nn.ar) — install the arm64 release into your SC Extensions folder
- [ClaudeCollider](https://github.com/jeremyruppel/claude-collider) — MCP server running and connected to Claude

## Installation

Clone or download this repo. No further installation needed — it's just `.scd` files.

Place your RAVE `.ts` model files in the `models/` folder. Models used by default:

| File                  | Character                |
|-----------------------|--------------------------|
| `birds.ts`            | organic, airy, avian     |
| `marinemammals.ts`    | deep, resonant, watery   |
| `wheel.ts`            | mechanical, metallic     |

Download models from Hugging Face: [Intelligent-Instruments-Lab/rave-models](https://huggingface.co/Intelligent-Instruments-Lab/rave-models/tree/main)

## How to use

### 1. Boot SuperCollider

Open `boot.scd` in the SuperCollider IDE. Select all (`Cmd+A`) and run (`Cmd+Enter`).

Wait for the post window to show:

```
════════════════════════════════════
  liveCoding-rave ready
  Models : birds | marinemammals | wheel
  Now talk to Claude.
════════════════════════════════════
```

### 2. Talk to Claude

With ClaudeCollider connected as an MCP server, open a conversation with Claude and start describing what you want:

> "Make a slow dark ambient texture using the birds model"

> "Play a beat with kick and hi-hats going through the marine mammals model, add some reverb"

> "Route the bass through the wheel model and the melody through birds, give them different rhythms"

Claude will generate SuperCollider patterns and execute them live. The audio is processed through the RAVE model you asked for.

### 3. Keep talking

You can change things mid-session:

> "Make the melody faster"
> "Switch the drums to the wheel model"
> "Add delay to the birds output"
> "Stop everything and start something more energetic"

## Signal flow

```
   Pbind (\cc_lead, \cc_kick, \cc_bass...)
         │
         ▼
   ~raveBuses[\birds | \marinemammals | \wheel]
         │
         ▼
   Ndef  (\rave_birds | \rave_marinemammals | \rave_wheel)
         │
         ▼
   ~cc.fx (reverb, delay, distortion...) [optional]
         │
         ▼
      speakers
```

Each model runs on its own bus and Ndef, so multiple models can process different instruments simultaneously.

## Standalone examples

The `examples/` folder contains standalone `.scd` files for using RAVE without ClaudeCollider — useful for learning or experimenting directly in SuperCollider:

| File     | Description                                      |
|----------|--------------------------------------------------|
| `1.scd`  | Single RAVE model, switchable, pattern-based     |
| `2.scd`  | Two models in parallel (birds + marinemammals)   |
| `3.scd`  | Microphone input processed through RAVE          |

These run independently — no ClaudeCollider needed.

## Stopping

Say "stop everything" to Claude, or in SuperCollider:

```supercollider
Cmd+.
```
