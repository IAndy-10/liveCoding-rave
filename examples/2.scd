/*
  RAVE Live Coding 2 — Two Models
  ════════════════════════════════
  birds       → melody + bass   (bus 0)
  marinemammals → drums + noise (bus 1)
*/


// ════════════════════════════════════════════════════════
// BLOCK 1 — Boot + load models
// ════════════════════════════════════════════════════════
(
s.options.memSize = 65536;

s.waitForBoot {
    var modelDir = "/Users/italo/Documents/Max 9/Packages/nn_tilde/models/";

    NN.load(\birds,         modelDir ++ "birds.ts");
    NN.load(\marinemammals, modelDir ++ "marinemammals.ts");

    s.sync;

    ~busBirds  = Bus.audio(s, 1);
    ~busMammals = Bus.audio(s, 1);

    SynthDef(\tone, { |out, freq = 440, amp = 0.3, atk = 0.01, rel = 0.5|
        var sig = Mix([Saw.ar(freq), Saw.ar(freq * 1.007)]) * 0.5;
        sig = sig * EnvGen.kr(Env.perc(atk, rel), doneAction: 2) * amp;
        Out.ar(out, sig);
    }).add;

    SynthDef(\pulse, { |out, freq = 60, amp = 0.5, atk = 0.005, rel = 0.3, width = 0.5|
        var sig = Pulse.ar(freq, width);
        sig = sig * EnvGen.kr(Env.perc(atk, rel), doneAction: 2) * amp;
        Out.ar(out, sig);
    }).add;

    SynthDef(\noise, { |out, amp = 0.3, atk = 0.01, rel = 0.2, ffreq = 800|
        var sig = BPF.ar(WhiteNoise.ar, ffreq, 0.3) * 10;
        sig = sig * EnvGen.kr(Env.perc(atk, rel), doneAction: 2) * amp;
        Out.ar(out, sig);
    }).add;

    "Ready — birds bus: %, marinemammals bus: %".format(~busBirds.index, ~busMammals.index).postln;
}
)


// ════════════════════════════════════════════════════════
// BLOCK 2 — RAVE processors
// ════════════════════════════════════════════════════════
(
Ndef(\birds, {
    var in  = InBus.ar(~busBirds, 1);
    var out = NN(\birds, \forward).ar(in, 2048);
    (out ! 2) * \gain.kr(0.8)
}).play;

Ndef(\mammals, {
    var in  = InBus.ar(~busMammals, 1);
    var out = NN(\marinemammals, \forward).ar(in, 2048);
    (out ! 2) * \gain.kr(0.8)
}).play;
)


// ════════════════════════════════════════════════════════
// BLOCK 3 — Patterns
// ════════════════════════════════════════════════════════

// — birds: melody ————————————————————————————————————————
(
Pdef(\melody,
    Pbind(
        \instrument, \tone,
        \out,      ~busBirds,
        \midinote, Pseq([60, 63, 67, 70, 72, 67], inf),
        \dur,      Pseq([0.25, 0.25, 0.5, 0.25, 0.5, 0.25], inf),
        \amp,      0.4,
        \rel,      0.5
    )
).play;
)

// — birds: bass ——————————————————————————————————————————
(
Pdef(\bass,
    Pbind(
        \instrument, \pulse,
        \out,      ~busBirds,
        \midinote, Pseq([36, 36, 43, 41], inf),
        \dur,      Pseq([0.5, 0.5, 0.25, 0.75], inf),
        \amp,      0.5,
        \rel,      0.4,
        \width,    Prand([0.3, 0.5, 0.7], inf)
    )
).play;
)

// — marinemammals: kick/snare —————————————————————————————
(
Pdef(\kick,
    Pbind(
        \instrument, \noise,
        \out,   ~busMammals,
        \ffreq, Pseq([150, 900, 150, 900, 150, 900, 150, 1400], inf),
        \dur,   0.25,
        \amp,   Pseq([0.9, 0.4, 0.7, 0.4], inf),
        \rel,   Pseq([0.3, 0.1, 0.2, 0.1], inf)
    )
).play;
)

// — marinemammals: hi noise texture ———————————————————————
(
Pdef(\texture,
    Pbind(
        \instrument, \noise,
        \out,   ~busMammals,
        \ffreq, Prand([2000, 3000, 4000, 6000], inf),
        \dur,   Prand([0.125, 0.25, 0.5], inf),
        \amp,   Prand([0.2, 0.3, 0.1], inf),
        \rel,   0.1
    )
).play;
)


// ════════════════════════════════════════════════════════
// CONTROLS
// ════════════════════════════════════════════════════════

// Gain per model
Ndef(\birds).set(\gain, 0.8);
Ndef(\mammals).set(\gain, 0.8);

// Stop individual patterns
Pdef(\melody).stop;
Pdef(\bass).stop;
Pdef(\kick).stop;
Pdef(\texture).stop;

// Stop everything
Pdef.all.do(_.stop);
Ndef(\birds).stop;
Ndef(\mammals).stop;
