/*
  liveCoding-rave — Boot File
  ═══════════════════════════
  Run this once at the start of every session.
  Select all (Cmd+A) → Cmd+Enter

  After boot, talk to Claude to start making music.
*/

~cc = CC.boot(onComplete: {

    var modelDir = thisProcess.nowExecutingPath.dirname +/+ "models/";

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

/*
### Talk to Claude

With ClaudeCollider connected as an MCP server, open a conversation with Claude and start describing what you want:

> "Make a slow dark ambient texture using the birds model"

> "Play a beat with kick and hi-hats going through the marine mammals model, add some reverb"

> "Route the bass through the wheel model and the melody through birds, give them different rhythms"

Claude will generate SuperCollider patterns and execute them live. The audio is processed through the RAVE model you asked for.

*/
