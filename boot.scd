/*
  liveCoding-rave — Boot File
  ═══════════════════════════
  Run this once at the start of every session.
  Select all (Cmd+A) → Cmd+Enter

  After boot, talk to Claude to start making music.
*/

~cc = CC.boot(onComplete: {

    var modelDir = "/Users/italo/Desktop/Audio Programming Languages/liveCoding-rave/models/";

    // ── Load RAVE models ──────────────────────────────────
    NN.load(\birds,         modelDir ++ "birds.ts");
    NN.load(\marinemammals, modelDir ++ "marinemammals.ts");
    NN.load(\wheel,         modelDir ++ "wheel.ts");

    s.sync;

    // ── Create one audio bus per model ────────────────────
    ~raveBuses = Dictionary.new;
    ~raveBuses[\birds]         = Bus.audio(s, 1);
    ~raveBuses[\marinemammals] = Bus.audio(s, 1);
    ~raveBuses[\wheel]         = Bus.audio(s, 1);

    // ── Create one RAVE Ndef per model ────────────────────
    Ndef(\rave_birds, {
        var in  = InBus.ar(~raveBuses[\birds], 1);
        var out = NN(\birds, \forward).ar(in, 2048);
        (out ! 2) * \gain.kr(0.8)
    }).play;

    Ndef(\rave_marinemammals, {
        var in  = InBus.ar(~raveBuses[\marinemammals], 1);
        var out = NN(\marinemammals, \forward).ar(in, 2048);
        (out ! 2) * \gain.kr(0.8)
    }).play;

    Ndef(\rave_wheel, {
        var in  = InBus.ar(~raveBuses[\wheel], 1);
        var out = NN(\wheel, \forward).ar(in, 2048);
        (out ! 2) * \gain.kr(0.8)
    }).play;

    // ── Done ──────────────────────────────────────────────
    "════════════════════════════════════".postln;
    "  liveCoding-rave ready".postln;
    "  Models : birds | marinemammals | wheel".postln;
    "  Buses  : ~raveBuses[\\birds|\\marinemammals|\\wheel]".postln;
    "  Ndefs  : \\rave_birds | \\rave_marinemammals | \\rave_wheel".postln;
    "  Now talk to Claude.".postln;
    "════════════════════════════════════".postln;
});
