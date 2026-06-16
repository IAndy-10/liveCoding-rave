// ============================================================
//  D DORIAN — Dark Rhythmic Patch
//  D Dorian: D E F G A B C D  (natural minor with raised 6th)
//  Degrees: 0 2 3 5 7 9 10 12
// ============================================================
// LLM used: Claude Code - Claude Sonnet 4.6


s.boot;

// -- Wait for server, then define everything
s.waitForBoot {

    // --------------------------------------------------------
    // SynthDefs
    // --------------------------------------------------------

    // Bass drone — deep, slow-attack sinewave with slight detune
    SynthDef(\drone, {
        |out=0, freq=73.42, amp=0.4, atk=2, rel=4|
        var sig, env;
        env = EnvGen.kr(Env.linen(atk, 8, rel, 1, \sine), doneAction: 0);
        sig = Mix([
            SinOsc.ar(freq,        0, 0.5),
            SinOsc.ar(freq * 1.001, 0, 0.3),   // slight detune
            SinOsc.ar(freq * 0.5,  0, 0.4)     // sub octave
        ]);
        sig = LPF.ar(sig, 2200);
        sig = sig * env * amp;
        Out.ar(out, sig ! 2);
    }).add;

    // Dark melodic voice — sine-based, slow, heavily reverbed (drone character)
    SynthDef(\darkPluck, {
        |out=0, freq=220, amp=0.3, pan=0, atk=0.06, rel=2.0|
        var sig, env, sigL, sigR, reverb;
        env = EnvGen.kr(Env.perc(atk, rel, 1, -4), doneAction: 2);
        sig = Mix([
            SinOsc.ar(freq,         0, 0.6),
            SinOsc.ar(freq * 1.002, 0, 0.3),   // slight detune (like drone)
            SinOsc.ar(freq * 0.5,   0, 0.25)   // sub presence
        ]);
        sig = LPF.ar(sig, freq * 3.5);
        sig = sig * env * amp;
        #sigL, sigR = Pan2.ar(sig, pan);
        reverb = FreeVerb2.ar(sigL, sigR, mix: 0.75, room: 0.9, damp: 0.65);
        Out.ar(out, reverb);
    }).add;

    // Percussive body — metallic low tom feel
    SynthDef(\darkHit, {
        |out=0, amp=0.5, freq=60|
        var sig, env, click, reverb;
        env   = EnvGen.kr(Env.perc(0.01, 2.4, 1, -4), doneAction: 2);
        click = EnvGen.kr(Env.perc(0.001, 0.02), doneAction: 0);
        sig   = SinOsc.ar(freq * XLine.kr(4, 1, 0.08), 0, 0.8);
        sig   = sig + (BPF.ar(WhiteNoise.ar, 800, 0.3) * click * 0.5);
        sig   = sig * env * amp;
		reverb = FreeVerb2.ar(sig, sig, mix: 0.9, room: 0.9, damp: 5.5);
        Out.ar(out, reverb);
    }).add;


    // Dark low transient — low-mid body with sub sine, matches darkHit energy
    SynthDef(\metalTick, {
        |out=0, amp=0.15, dur=0.18|
        var sig, env, reverb;
        env = EnvGen.kr(Env.perc(0.003, dur, 1, -5), doneAction: 2);
        sig = BPF.ar(WhiteNoise.ar, 1600, 0.4);           // low-mid crunch
        sig = sig + (SinOsc.ar(120 * XLine.kr(2, 1, 0.04), 0, 0.5)); // sub body
        sig = LPF.ar(sig, 2800);
        sig = sig * env * amp;
        reverb = FreeVerb2.ar(sig, sig, mix: 0.65, room: 0.85, damp: 0.7);
        Out.ar(out, reverb);
    }).add;

    // Delay effect bus — dark echoes, LPF'd to stay in the low-mid shadow
    SynthDef(\darkDelay, {
        |in=4, out=0, delaytime=0.375, decay=4, amp=0.4|
        var sig;
        sig = In.ar(in, 2);
        sig = CombL.ar(sig, 1.0, delaytime, decay);
        sig = LPF.ar(sig, 1400);   // kill highs from echoes — keep them murky
        sig = sig * amp;
        Out.ar(out, sig);
    }).add;

    s.sync;

    // --------------------------------------------------------
    // D Dorian scale in MIDI (two octaves, rooted at D3 = 50)
    // Intervals: 0 2 3 5 7 9 10 12
    // --------------------------------------------------------
    ~dorian = [50, 52, 53, 55, 57, 59, 60, 62,   // D3 octave
               62, 64, 65, 67, 69, 71, 72, 74];  // D4 octave

    // --------------------------------------------------------
    // Effects bus setup
    // --------------------------------------------------------
    ~fxBus = Bus.audio(s, 2);
    ~delayNode = Synth(\darkDelay, [
        \in,        ~fxBus.index,
        \out,       0,
        \delaytime, 0.375,   // dotted 8th at ~80 bpm
        \decay,     3.5,
        \amp,       0.35
    ]);

    s.sync;

    // --------------------------------------------------------
    // Drone (sustained D bass)
    // --------------------------------------------------------
    Synth(\drone, [\freq, 36.midicps, \amp, 0.35]);  // D1

    // --------------------------------------------------------
    // Main pattern — Pbind using dark pluck voice
    // --------------------------------------------------------
    ~melody = Pbind(
        \instrument, \darkPluck,
        \out,        ~fxBus,          // route through delay bus
        \scale,      Scale.dorian,
        \root,       2,               // D (C=0, D=2)
        \octave,     Pwrand([3,4,5], [0.2, 0.6, 0.2], inf),
        \degree,     Pseq([
            // Hypnotic motif — resolves back to root
            0, 5, 3, 7,
            0, 5, 2, 6,
            0, 4, 3, 7,
            \rest, 5, 3, 0
        ], inf),
        \dur,        Pseq([0.5, 0.5, 0.5, 0.75,
                           0.5, 0.5, 0.5, 0.75,
                           0.5, 0.5, 0.5, 1.0,
                           0.25, 0.5, 0.5, 1.0], inf),
        \amp,        Pexprand(0.18, 0.35, inf),
        \pan,        Pwhite(-0.5, 0.5, inf),
        \atk,        Pwhite(0.04, 0.12, inf),
        \rel,        Pwhite(1.5, 3.0, inf)
    ).play(TempoClock(80/60));

    // --------------------------------------------------------
    // Dark rhythmic pulse — kick-like pattern at 80 bpm
    // Pattern:  X . . X  . X . .  X . X .  . . X .
    // --------------------------------------------------------
    ~kick = Pbind(
        \instrument, \darkHit,
        \freq,       Pxrand([55, 60, 52], inf),
        \amp,        Pseq([0.7, 0, 0, 0,  0, 0, 0, 0,
                           0.7, 0, 0, 0,   0, 0,  0, 0], inf),
        \dur,        2.0
    ).play(TempoClock(80/60));

    // --------------------------------------------------------
    // Metal tick — sparse hi-hat feel
    // --------------------------------------------------------
    ~hats = Pbind(
        \instrument, \metalTick,
        \amp,        Pseq([0, 0.12, 0, 0.08,  0.15, 0, 0.1, 0], inf),
        \dur,        Pseq([0.5, 0.5, 0.5, 0.5,
                           0.25, 0.25, 0.25, 0.75], inf)
    ).play(TempoClock(80/60));

    // --------------------------------------------------------
    // Accent — low D stabs on beat 1 and offbeat
    // --------------------------------------------------------
    ~stab = Pbind(
        \instrument, \darkPluck,
        \out,        ~fxBus,
        \scale,      Scale.dorian,
        \root,       2,
        \degree,     Pseq([0, \rest, \rest, 0, \rest, 7, \rest, \rest], inf),
        \octave,     3,
        \dur,        0.5,
        \amp,        0.4,
        \pan,        -0.4,
        \atk,        0.02,
        \rel,        2.0
    ).play(TempoClock(80/60));

    "D Dorian dark rhythm patch loaded. All patterns running.".postln;
    "Stop with: ~melody.stop; ~kick.stop; ~hats.stop; ~stab.stop;".postln;
};

// ============================================================
// STOP ALL
// ============================================================
//~melody.stop; ~kick.stop; ~hats.stop; ~stab.stop;
//s.freeAll;
