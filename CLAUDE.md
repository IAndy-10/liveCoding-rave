# liveCoding-rave — Claude Reference

Live coding with RAVE neural audio models and ClaudeCollider. Claude connects first (triggering a scsynth reboot), then the user runs `boot.scd`. Claude's job is to compose and play patterns.

## Before Playing Anything

Follow this order at the start of every session:

1. **Ask: Is your audio monitoring set up?**

2. **Run a dummy `cc_execute` first** — before the user runs `boot.scd`.
   ClaudeCollider's MCP server reboots scsynth on its very first connection each session. Do this intentionally so the reboot happens on an empty server.

   ```supercollider
   "Claude connected — ready for boot.scd".postln;
   ```

3. **Ask the user to run `boot.scd`** after the cc_execute above completes.
   The user must open `boot.scd` in the SC IDE, select all (`Cmd+A`), and run (`Cmd+Enter`). Wait for:
   ```
   ════════════════════════════════════
     liveCoding-rave ready
     ...
     Now talk to Claude.
   ════════════════════════════════════
   ```

4. **Confirm boot** with:
   ```supercollider
   File.readAllString("/tmp/rave_synthdef.sc").interpret;
   ```
   If you get a file-not-found error, ask the user to re-run `boot.scd`.

## Two-Sclang Architecture

ClaudeCollider's MCP server runs its **own sclang process**, separate from the SC IDE's sclang. Both talk to the **same scsynth server** (shared audio), but do NOT share language state.

**The key insight of the SynthDef approach:** SynthDefs are stored on scsynth itself, not in any sclang process. `boot.scd` defines `\rave_birds` and sends it to scsynth. Claude's sclang can then use `\instrument, \rave_birds` in any Pbind — no bus, no Ndef, no routing needed.

Because SC IDE's sclang does not create any synths during performance, **only CC MCP creates nodes** → no nodeID collision between the two processes.

| What | SC IDE sclang | CC MCP sclang (cc_execute) |
|---|---|---|
| `\rave_birds` SynthDef | ✅ defined by boot.scd | ✅ available on scsynth |
| `NN` model registry | ✅ loaded by boot.scd | ❌ empty — do not call `NN.load` |
| `Pdef` patterns | — | ✅ create here via cc_execute |
| `~raveBuses`, `Ndef` | ❌ not used anymore | ❌ not used anymore |

## Signal Flow

```
Pbind(\instrument, \rave_birds, \freq, ...)
    → SynthDef(\rave_birds) — generates audio + runs NN.ar inline
    → hardware output (stereo)

optionally:
    → ~cc.fx (reverb, delay, etc.)
```

## Available RAVE SynthDefs

| SynthDef     | Model   | Character              |
|--------------|---------|------------------------|
| `\rave_birds`| birds   | organic, airy, avian   |

> More models (`marinemammals`, `wheel`) can be added to `boot.scd` when needed.

## Playing a Pattern Through RAVE

Use `\rave_birds` directly as the instrument:

```supercollider
Pdef(\melody, Pbind(
    \instrument, \rave_birds,
    \freq, 440,
    \dur, 0.5,
    \amp, 0.4,
    \atk, 0.1,
    \rel, 2.0,
    \pan, 0,
)).play;
```

### SynthDef Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `\freq`   | 440     | Pitch in Hz — keep above 200 Hz for best RAVE transformation |
| `\amp`    | 0.5     | Source amplitude |
| `\gate`   | 1       | Envelope gate (Pbind manages this automatically) |
| `\atk`    | 0.01    | Attack time in seconds |
| `\rel`    | 2       | Release time in seconds |
| `\pan`    | 0       | Stereo pan (-1 to 1) |
| `\gain`   | 0.8     | RAVE output gain (0.0–1.0) |
| `\out`    | 0       | Output bus (default = main hardware out) |

## Stopping

```supercollider
// Stop one pattern
Pdef(\melody).stop;

// Stop everything
~cc.stop;
```

## cc_execute Syntax Rules

### `wait` outside a Routine throws an error

```supercollider
// ❌ breaks
Pdef(\a).play;
0.5.wait;
Pdef(\b).play;

// ✅ works
Routine {
    Pdef(\a).play;
    0.5.wait;
    Pdef(\b).play;
}.play;
```

### `var` inside outer `()` causes a syntax error

```supercollider
// ❌ breaks
(
var x = 440;
Pdef(\a, Pbind(\freq, x)).play;
)

// ✅ works — no outer parens needed
Pdef(\a, Pbind(\freq, 440)).play;
```

### Never call `NN.load` from cc_execute

The CC MCP sclang's `NN` registry is always empty. The model is already loaded on scsynth by `boot.scd` — `\rave_birds` just works.

### Never use custom SynthDef from cc_execute

`SynthDef.add` fails silently from cc_execute — CC MCP's `s` shows the server as "not running". Use only `\rave_birds` (defined by boot.scd) and built-in CC instruments (`\cc_pad`, `\cc_lead`, `\cc_bass`, `\cc_kick`, `\cc_snare`, `\cc_hat`).

## 48kHz / RAVE Sample Rate Issue

RAVE models are trained at **44.1kHz**. If the SC server runs at **48kHz**, `NN.ar` is silent.

Fix: quit SuperCollider, relaunch, re-run `boot.scd` — it sets 44100 Hz automatically.

Check anytime:
```supercollider
s.sampleRate.postln;
```

## Danger: Never use `s.freeAll`

Kills CC's limiter/output chain permanently. Use `Pdef(\name).stop` or `~cc.stop` instead.

## Notes

- **Frequency range matters.** The `\birds` model works best above 200 Hz. For dark/low textures, use octave 4+ (C4 = 261 Hz) rather than bass registers.
- `cc_status` always shows `Server: stopped` / `limiter off` — this is a known artifact of the two-sclang architecture. Ignore it. If audio plays, everything is working.
- All `cc_*` drums need `\freq, 48` — but with the SynthDef approach, drums can be played as `\rave_birds` with `\freq, 48` too.
- The RAVE model is mono internally; the SynthDef outputs stereo via `Pan2.ar`.
