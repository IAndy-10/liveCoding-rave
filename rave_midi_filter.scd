/*
  NeoChucao — rave_midi.scd
  ══════════════════════════
  MIDI keyboard → latent space → RAVE birds.ts decoder → audio.

  Runtime controls:
    Mod wheel (CC 1) → z2 (timbre morph), pushed to all active voices
    CC 2 knob        → noise_scale (z3–z15 chaos), affects next note-on

  Blocks:
    1   — Boot server, load model, define SynthDef
    2   — Connect MIDI keyboard, start playing
    3   — Open GUI controls
    4   — Stop everything (MIDI + voices)

LLM used: Claude Code - Claude Sonnet 4.6
*/
s.boot

// ════════════════════════════════════════════════════════
// BLOCK 1 — Boot, load model, define SynthDef
// Run once per session. Wait for "Ready." before Block 2.
// ════════════════════════════════════════════════════════
(
s.options.memSize = 65536;
//s.options.numInputBusChannels  = 1;
s.options.numOutputBusChannels = 2;
s.options.inDevice_("MacBook Air Microphone");
s.options.outDevice_("MacBook Air Speakers");
s.waitForBoot {

    // ── Load RAVE model ───────────────────────────────────
    NN.load(\birds, PathName(thisProcess.nowExecutingPath).pathOnly +/+ "/models/birds.ts");
    s.sync;
    NN(\birds).describe;

    // ── SynthDef ──────────────────────────────────────────
    SynthDef(\rave_midi, { |
        gate = 1, amp = 0.5,
        atk  = 0.8, dec = 0.1, sus = 0.9, rel = 1.5,
        z0  = 0, z1  = 0, z2  = 0, z3  = 0,
        z4  = 0, z5  = 0, z6  = 0, z7  = 0,
        z8  = 0, z9  = 0, z10 = 0, z11 = 0,
        z12 = 0, z13 = 0, z14 = 0, z15 = 0,
        compThresh = 0.4, compRatio = 0.3,
        chMix = 0.4,
        rvMix = 0.3, rvRoom = 0.7, rvDamp = 0.5 |

        var latent = [z0, z1, z2, z3, z4, z5, z6, z7,
                      z8, z9, z10, z11, z12, z13, z14, z15]
                        .collect({ |z| Lag.kr(z, 0.05) });
        var sig = NN(\birds, \decode).ar(latent, 2048);
        var env = EnvGen.kr(
            Env.adsr(atk, dec, sus, rel),
            gate:       gate,
            doneAction: 2
        );
        var dry  = sig * env * amp;

        // Compressor — tames amplitude swell from attack/decay shape
        var comp = Compander.ar(dry, dry,
            thresh:     compThresh,
            slopeBelow: 1.0,
            slopeAbove: compRatio,
            clampTime:  0.01,
            relaxTime:  0.1
        );

        // Chorus — 3 LFO-modulated delay lines, evenly phased
        var chorus = Mix.fill(3, { |i|
            var rate = [0.18, 0.22, 0.15][i];
            var phase = [0, 2.09, 4.19][i];       // 0, 2π/3, 4π/3
            var mod  = SinOsc.kr(rate, phase) * 0.003;
            DelayL.ar(comp, 0.05, 0.015 + mod)
        }) / 3;
        var chorused = (comp * (1 - chMix)) + (chorus * chMix);

        // Reverb
        var wet = FreeVerb2.ar(chorused, chorused, mix: rvMix, room: rvRoom, damp: rvDamp);
        Out.ar(0, wet);
    }).add;
    s.sync;

    // ── Latent mapping (mirrors latent_map.py) ────────────
    ~noteMin     = 36;
    ~noteMax     = 96;
    ~latentRange = 2.0;
    ~noiseScale  = 0.0;
    ~ccState     = Dictionary.new;
    ~voices      = Dictionary.new;  // MIDI note → Synth

    // Session-fixed Gaussian noise per MIDI note (z3–z15).
    // Same note always gets the same noise vector this session.
    ~noteNoise = Array.fill(128, { Array.fill(13, { gauss(0, 1) }) });

    // Map MIDI value [lo, hi] → [-latentRange, +latentRange]
    ~midiToZ = { |value, lo = 0, hi = 127|
        var t = ((value - lo) / (hi - lo)).clip(0, 1);
        ~latentRange.neg + (t * ~latentRange * 2);
    };

    // Build a 16-element latent array from a note-on event
    ~buildLatent = { |note, vel|
        var noise = ~noteNoise[note];
        var z = Array.newClear(16);
        z[0]  = ~midiToZ.(note, ~noteMin, ~noteMax);
        z[1]  = ~midiToZ.(vel);
        z[2]  = ~midiToZ.(~ccState.at(1) ?? { 64 });
        13.do { |i| z[i + 3] = noise[i] * ~noiseScale };
        z
    };

    "Ready. Run Block 2 to connect MIDI.".postln;
};
)


// ════════════════════════════════════════════════════════
// BLOCK 2 — Connect MIDI, start playing
// ════════════════════════════════════════════════════════
(
MIDIClient.init;
MIDIIn.connectAll;

// ── Note on ───────────────────────────────────────────────
MIDIdef.noteOn(\noteOn, { |vel, note|
    var z, synth;

    // note_on with vel=0 is a note_off on some keyboards
    if (vel == 0) {
        ~voices[note] !? { |v| v.set(\gate, 0); ~voices.removeAt(note) };
    } {
        z = ~buildLatent.(note, vel);
        // Release any existing voice on this pitch first
        ~voices[note] !? { |v| v.set(\gate, 0) };
        synth = Synth(\rave_midi, [
            \amp, (vel / 127) * 0.8,
            \z0,  z[0],  \z1,  z[1],  \z2,  z[2],  \z3,  z[3],
            \z4,  z[4],  \z5,  z[5],  \z6,  z[6],  \z7,  z[7],
            \z8,  z[8],  \z9,  z[9],  \z10, z[10], \z11, z[11],
            \z12, z[12], \z13, z[13], \z14, z[14], \z15, z[15],
        ]);
        ~voices[note] = synth;
        ("note_on  note=" ++ note ++ " vel=" ++ vel
            ++ "  z0=" ++ z[0].round(0.01)
            ++ " z1=" ++ z[1].round(0.01)).postln;
    };
});

// ── Note off ──────────────────────────────────────────────
MIDIdef.noteOff(\noteOff, { |vel, note|
    ~voices[note] !? { |v|
        v.set(\gate, 0);
        ~voices.removeAt(note);
    };
    ("note_off note=" ++ note).postln;
});

// ── CC ────────────────────────────────────────────────────
MIDIdef.cc(\cc, { |val, num|
    ~ccState[num] = val;

    // CC 1 — mod wheel → z2, pushed to all active voices
    if (num == 1) {
        var z2 = ~midiToZ.(val);
        ~voices.do { |v| v.set(\z2, z2) };
        ("mod wheel  z2=" ++ z2.round(0.01)).postln;
    };

    // CC 2 — assignable knob → noise_scale (0–3.0)
    if (num == 2) {
        ~noiseScale = (val / 127) * 3.0;
        ("noise_scale=" ++ ~noiseScale.round(0.01)).postln;
    };
});

"MIDI connected — play your keyboard.".postln;
"  Mod wheel (CC 1) → z2 timbre".postln;
"  CC 2 knob        → noise_scale (z3-z15 chaos)".postln;
"  Run Block 3 to open de GUI.".postln;
)


// ════════════════════════════════════════════════════════
// BLOCK 3 — GUI Controls
// Run after Block 2. Can be reopened at any time.
// ════════════════════════════════════════════════════════
(
var bgColor  = Color(0.05, 0.05, 0.08);
var lblColor = Color(0.65, 0.65, 0.85);
var valColor = Color(0.85, 0.85, 1.0);
var fnt      = Font("Monaco", 11);

var win = Window("NeoChucao Controls", Rect(100, 100, 400, 350))
    .background_(bgColor)
    .front;

// Helper — one labelled slider row.
var makeRow = { |label, y, initVal, lo, hi, action|
    var valLabel, sl;

    StaticText(win, Rect(10, y, 140, 24))
        .string_(label)
        .stringColor_(lblColor)
        .font_(fnt);

    valLabel = StaticText(win, Rect(340, y, 50, 24))
        .string_(initVal.round(0.01).asString)
        .stringColor_(valColor)
        .font_(fnt)
        .align_(\right);

    sl = Slider(win, Rect(155, y + 2, 178, 20))
        .value_((initVal - lo) / (hi - lo))
        .background_(Color(0.12, 0.12, 0.2));

    sl.action_({
        var mapped = lo + (sl.value * (hi - lo));
        valLabel.string_(mapped.round(0.01).asString);
        action.(mapped);
    });

    sl
};

// ── Mod wheel → z2  (-2 to +2, default 0) ────────────────
makeRow.("Mod wheel  (z2)", 20, 0.0, -2.0, 2.0, { |val|
    ~ccState[1] = ((val + 2.0) / 4.0 * 127).round.asInteger;
    ~voices.do { |v| v.set(\z2, val) };
});

// ── Noise scale → z3-z15  (0 to 3, default 0) ────────────
makeRow.("Noise  (z3–z15)", 75, 0.0, 0.0, 3.0, { |val|
    ~noiseScale = val;
});

// ── Latent range → z0/z1/z2 width  (0.5 to 3, default 2) ─
makeRow.("Latent range", 130, 2.0, 0.5, 3.0, { |val|
    ~latentRange = val;
});

// ── Comp threshold  (0.1 to 1.0, default 0.4) ────────────
makeRow.("Comp threshold", 185, 0.4, 0.1, 1.0, { |val|
    ~voices.do { |v| v.set(\compThresh, val) };
});

// ── Chorus mix  (0 to 1, default 0.4) ────────────────────
makeRow.("Chorus mix", 240, 0.4, 0.0, 1.0, { |val|
    ~voices.do { |v| v.set(\chMix, val) };
});

// ── Reverb mix  (0 to 1, default 0.3) ────────────────────
makeRow.("Reverb mix", 295, 0.3, 0.0, 1.0, { |val|
    ~voices.do { |v| v.set(\rvMix, val) };
});
)


// ════════════════════════════════════════════════════════
// BLOCK 4 — Stop
// ════════════════════════════════════════════════════════
(
~voices.do { |v| v.set(\gate, 0) };
~voices.clear;
MIDIdef.freeAll;
"Stopped. All voices released, MIDI disconnected.".postln;
)

s.quit;

