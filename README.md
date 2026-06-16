# NeoChucao

SuperCollider scripts for live performance and generative composition with RAVE neural audio models.

> Developed with LLM assistance — Claude Sonnet 4.6 (Anthropic).

---

## Files

| File | Description |
|---|---|
| `rave_midi_filter.scd` | MIDI keyboard → RAVE latent space → audio. Maps pitch, velocity, and mod wheel to 16 latent dimensions. Polyphonic voice manager with compressor, chorus, and reverb. Includes a GUI. |
| `d_dorian_dark.scd` | Generative D Dorian dark rhythmic patch — bass drone, melodic voice, kick, hi-hats, and stabs routed through a delay bus at 80 bpm. |

---

## Prerequisites

- [SuperCollider](https://supercollider.github.io)
- [nn.ar](https://github.com/elgiano/nn.ar) — install the arm64 release into your SC Extensions folder

---

## Model

Place your RAVE `.ts` model file in the `models/` folder:

```
models/
└── birds.ts
```

Download the birds model from Hugging Face and rename it to `birds.ts`:

**[birds_motherbird_b2048_r48000_z16.ts](https://huggingface.co/Intelligent-Instruments-Lab/rave-models/blob/main/birds_motherbird_b2048_r48000_z16.ts)**

---

## How to use

### rave_midi_filter.scd

Open in the SuperCollider IDE and run each block in order:

1. **Block 1** — boots the server, loads the RAVE model, defines the SynthDef. Wait for `"Ready."`.
2. **Block 2** — connects your MIDI keyboard and starts the voice manager.
3. **Block 3** *(optional)* — opens a GUI with sliders for mod wheel, noise, reverb, chorus, and more.
4. **Block 4** — stops all voices and disconnects MIDI.

### d_dorian_dark.scd

Open in the SuperCollider IDE, select all (`Cmd+A`) and run (`Cmd+Enter`). All patterns start automatically.

Stop with:
```supercollider
~melody.stop; ~kick.stop; ~hats.stop; ~stab.stop;
```
