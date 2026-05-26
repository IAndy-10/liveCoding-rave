# liveCoding-rave — Claude Reference

This session combines **ClaudeCollider** (CC) with **RAVE neural audio models** via nn.ar.
Use CC tools and `cc_execute` as normal. Route patterns through RAVE buses for neural timbre transformation.

## Signal Flow

```
Pbind (cc_* synth)
    → ~raveBuses[\model]   (audio bus)
    → Ndef(\rave_model)    (RAVE neural processing)
    → hardware output

optionally:
    → ~cc.fx (reverb, delay, etc.)
    → hardware output
```

## Available RAVE Models

| Model key       | Ndef name              | Bus                          | Character              |
|-----------------|------------------------|------------------------------|------------------------|
| `\birds`        | `\rave_birds`          | `~raveBuses[\birds]`         | organic, airy, avian   |
| `\marinemammals`| `\rave_marinemammals`  | `~raveBuses[\marinemammals]` | deep, resonant, watery |
| `\wheel`        | `\rave_wheel`          | `~raveBuses[\wheel]`         | mechanical, metallic   |

## Routing a Pattern Through RAVE

Set `\out` to the model's bus in any Pbind:

```supercollider
Pdef(\melody, Pbind(
    \instrument, \cc_lead,
    \out, ~raveBuses[\birds],
    \freq, 440,
    \dur, 0.25,
    \amp, 0.4
)).play;
```

Any `cc_*` synth works as a source: drums, bass, leads, pads, etc.

## Adjusting RAVE Output Gain

```supercollider
Ndef(\rave_birds).set(\gain, 0.8);         // 0.0 - 1.0
Ndef(\rave_marinemammals).set(\gain, 0.6);
Ndef(\rave_wheel).set(\gain, 0.9);
```

## Chaining RAVE with CC Effects

Route a RAVE Ndef into CC effects just like any other source:

```supercollider
~cc.fx.load(\reverb);
~cc.fx.route(\rave_birds, \fx_reverb);
~cc.fx.set(\fx_reverb, \mix, 0.5, \room, 0.8);

~cc.fx.load(\delay);
~cc.fx.route(\rave_marinemammals, \fx_delay);
```

## Using Multiple Models Simultaneously

Each model has its own bus and Ndef, so they run in parallel:

```supercollider
// Melody → birds
Pdef(\melody, Pbind(\instrument, \cc_lead, \out, ~raveBuses[\birds], \freq, 440, \dur, 0.5)).play;

// Drums → marinemammals
Pdef(\kick, Pbind(\instrument, \cc_kick, \out, ~raveBuses[\marinemammals], \freq, 48, \dur, 1)).play;

// Bass → wheel
Pdef(\bass, Pbind(\instrument, \cc_bass, \out, ~raveBuses[\wheel], \freq, 55, \dur, 0.5)).play;
```

## Stopping

```supercollider
// Stop a pattern
Pdef(\melody).stop;

// Stop a RAVE model
Ndef(\rave_birds).stop;

// Stop everything
~cc.stop;
```

## Notes

- All `cc_*` drums need `\freq, 48` to sound correct — this applies when routed through RAVE too.
- RAVE models are mono internally. The Ndef duplicates to stereo with `! 2`.
- Boot order matters: always run `boot.scd` before asking Claude to play anything.
- `cc_execute` is the tool to use for Pdef/Ndef definitions and RAVE routing.
