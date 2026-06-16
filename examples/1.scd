/*
  RAVE Live Coding — SuperCollider
  ════════════════════════════════
  Run each block with: select it → Cmd+Enter
  Stop all sound:      Cmd+.
  Recompile classes:   Cmd+Shift+L

  Models available:
    \birds  \marinemammals  \wavetable  \wheel  \effects

  Built with Claude Code, Claude Sonnet 4.6
*/


// ════════════════════════════════════════════════════════
// BLOCK 1 — Boot server + load models
// Run once at the start of your session.
// ════════════════════════════════════════════════════════
(
s.options.memSize = 65536;

// Change the location with your own models
s.waitForBoot {
    var modelDir = "/Users/italo/Desktop/Audio\ Programming\ Languages/liveCoding-rave/models/";

    NN.load(\birds,         modelDir ++ "birds.ts");
    NN.load(\marinemammals, modelDir ++ "marinemammals.ts");
    NN.load(\wheel,         modelDir ++ "wheel.ts");

    s.sync;

    // Print available methods for each model
    [\birds, \marinemammals, \wheel].do { |m| NN(m).describe };

    // Shared audio bus: sound sources → RAVE
    ~srcBus = Bus.audio(s, numChannels: 1);

    // Source synths
    SynthDef(\tone, { |out, freq = 440, amp = 0.3, atk = 0.01, rel = 0.5, pan = 0|
        var sig = Mix([
            Saw.ar(freq),
            Saw.ar(freq * 1.007)
        ]) * 0.5;
        sig = sig * EnvGen.kr(Env.perc(atk, rel), doneAction: 2) * amp;
        Out.ar(out, Pan2.ar(sig, pan)[0]); // mono to bus
    }).add;

    SynthDef(\noise, { |out, amp = 0.3, atk = 0.01, rel = 0.3, ffreq = 800|
        var sig = BPF.ar(WhiteNoise.ar, ffreq, 0.3);
        sig = sig * EnvGen.kr(Env.perc(atk, rel), doneAction: 2) * amp * 10;
        Out.ar(out, sig);
    }).add;

    SynthDef(\pulse, { |out, freq = 60, amp = 0.5, atk = 0.005, rel = 0.2, width = 0.5|
        var sig = Pulse.ar(freq, width);
        sig = sig * EnvGen.kr(Env.perc(atk, rel), doneAction: 2) * amp;
        Out.ar(out, sig);
    }).add;

    "Ready. ~srcBus index: %".format(~srcBus.index).postln;
}
)


// ════════════════════════════════════════════════════════
// BLOCK 2 — RAVE processor
// Run after Block 1. Re-run anytime to change the model.
// ════════════════════════════════════════════════════════
(
Ndef(\rave, {
    var in  = InBus.ar(~srcBus, 1);
    var out = NN(\birds, \forward).ar(in, 2048); // ← change model here
    out = out ! 2; // mono → stereo
    out * \gain.kr(0.8)
}).play;
)

// Switch model live — re-evaluate with a different model:
Ndef(\rave, { var in = InBus.ar(~srcBus, 1); (NN(\marinemammals, \forward).ar(in, 2048) ! 2) * \gain.kr(0.8) }).play;


Ndef(\rave, { var in = InBus.ar(~srcBus, 1); (NN(\wheel,         \forward).ar(in, 2048) ! 2) * \gain.kr(0.8) }).play;

// Wet/dry mix (0 = dry, 1 = full RAVE)
Ndef(\rave).set(\gain, 0.8);


// ════════════════════════════════════════════════════════
// BLOCK 3 — Patterns (live code these freely)
// Evaluate/re-evaluate any Pdef while music is running.
// ════════════════════════════════════════════════════════

// — Melody through RAVE ——————————————————————————————————
(
Pdef(\melody,
    Pbind(
        \instrument, \tone,
        \out,  ~srcBus,
        \midinote, Pseq([60, 63, 67, 70, 72, 70, 67, 63], inf),
        \dur,  Pseq([0.25, 0.25, 0.25, 0.25, 0.5, 0.25, 0.25, 0.5], inf),
        \amp,  0.4,
        \rel,  0.4
    )
).play;
)

// — Drums through RAVE ———————————————————————————————————
(
Pdef(\drums,
    Pbind(
        \instrument, \noise,
        \out,   ~srcBus,
        \ffreq, Pseq([200, 800, 200, 800, 200, 800, 1200, 800], inf),
        \dur,   0.25,
        \amp,   Pseq([0.8, 0.3, 0.6, 0.3], inf),
        \rel,   Pseq([0.3, 0.1, 0.2, 0.1], inf)
    )
).play;
)

// — Bass through RAVE ————————————————————————————————————
(
Pdef(\bass,
    Pbind(
        \instrument, \pulse,
        \out,     ~srcBus,
        \midinote, Pseq([36, 36, 43, 41], inf),
        \dur,     Pseq([0.5, 0.5, 0.25, 0.75], inf),
        \amp,     0.6,
        \rel,     0.4,
        \width,   Prand([0.3, 0.5, 0.7], inf)
    )
).play;
)

// — Stop individual patterns ————————————————————————————
Pdef(\melody).stop;
Pdef(\drums).stop;
Pdef(\bass).stop;

// — Stop everything —————————————————————————————————————
Pdef.all.do(_.stop);
Ndef(\rave).stop;
