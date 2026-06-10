/*
  NeoChucao — RAVE Decoder SynthDef
  ══════════════════════════════════
  Compile this once to produce rave_decoder.scsyndef.

  Prerequisites:
    - nn.ar extension installed in SC Extensions folder
    - birds.ts model loaded via:  NN.load(\birds, "/path/to/models/birds.ts")

  To compile:
    1. Boot the SC server (Cmd+B)
    2. Load the birds model (run the NN.load block below)
    3. Select the SynthDef block and run it (Cmd+Enter)
    4. Verify rave_decoder.scsyndef appears in the synthdefs/ folder

  To smoke test:
    Run the test block at the bottom.
*/


// ════════════════════════════════════════════════════════
// BLOCK 1 — Boot server + load model
// Run once per session before compiling the SynthDef.
// ════════════════════════════════════════════════════════
(
s.options.memSize = 65536;
s.waitForBoot {
    NN.load(\birds, thisProcess.nowExecutingPath.dirname +/+ "../models/birds.ts");
    s.sync;
    NN(\birds).describe;
    "birds.ts model loaded".postln;
};
)

// ════════════════════════════════════════════════════════
// BLOCK 2 — Compile SynthDef → rave_decoder.scsyndef
// ════════════════════════════════════════════════════════
(
SynthDef(\rave_decoder, { |

      out = 0,                              // target bus (set to FX_BUS_ID from Python)
      gate = 1, amp = 0.5,
      z0  = 0, z1  = 0, z2  = 0, z3  = 0,
      z4  = 0, z5  = 0, z6  = 0, z7  = 0,
      z8  = 0, z9  = 0, z10 = 0, z11 = 0,
      z12 = 0, z13 = 0, z14 = 0, z15 = 0 |

    var latent = [z0, z1, z2, z3, z4, z5, z6, z7,
                  z8, z9, z10, z11, z12, z13, z14, z15]
                    .collect({ |z| Lag.kr(z, 0.05) });

    var sig = NN(\birds, \decode).ar(latent, 2048);
    var env = EnvGen.kr(
        Env.adsr(attackTime: 0.001, decayTime: 3.1, sustainLevel: 3.8, releaseTime: 2.5),
        gate:       gate,
        doneAction: 2
    );

   Out.ar(out, (sig ! 2) * env * amp);


  }).store(dir: PathName(thisProcess.nowExecutingPath).pathOnly);
"SynthDef written and sent to server".postln;
("SynthDef written to: " ++ thisProcess.nowExecutingPath.dirname).postln;
)


// ════════════════════════════════════════════════════════
// BLOCK 3 — Smoke test
// Run after blocks 1 and 2. Should produce RAVE audio.
// ════════════════════════════════════════════════════════

// Test 1: prior (all z = 0) — RAVE baseline character
(
~test = Synth(\rave_decoder, [amp: 0.8]);
)
~test.set(\gate, 0);  // release

// Test 2: non-zero latent — should sound different from test 1
(
~test = Synth(\rave_decoder, [
    \amp, 0.6,
    \z0,  1.2,
    \z1, -0.8,
    \z2,  0.5
]);
)
~test.set(\gate, 0);
// release

// Test 3: polyphony — three simultaneous voices
(
~v1 = Synth(\rave_decoder, [\amp, 0.3, \z0,  1.5]);
~v2 = Synth(\rave_decoder, [\amp, 0.3, \z0,  0.0]);
~v3 = Synth(\rave_decoder, [\amp, 0.3, \z1, -1.5]);
)
~v1.set(\gate, 0); ~v2.set(\gate, 0); ~v3.set(\gate, 0);


// Test 4: LFO modulation via control buses
// Each z param is driven by a separate LFO synth — mirrors how supriya will push values
(
~busZ0 = Bus.control(s, 1);
~busZ1 = Bus.control(s, 1);
~busZ2 = Bus.control(s, 1);

// Nice sound bellow :)
~lfo0 = { Out.kr(~busZ0, SinOsc.kr(0.3,  0,    1.2)) }.play;  // slow sweep on z0
~lfo1 = { Out.kr(~busZ1, SinOsc.kr(0.7,  pi/2, 0.8)) }.play;  // faster sweep on z1
~lfo2 = { Out.kr(~busZ2, SinOsc.kr(0.15, pi,   0.5)) }.play;  // slow drift on z2

~test = Synth(\rave_decoder, [\amp, 0.5]);
~test.map(\z0, ~busZ0, \z1, ~busZ1, \z2, ~busZ2);
)

// Release
~lfo0.free; ~lfo1.free; ~lfo2.free;
~busZ0.free; ~busZ1.free; ~busZ2.free;
~test.set(\gate, 0);
