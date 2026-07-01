/*
  liveCoding-rave — Boot File
  ═══════════════════════════
  Run this once at the start of every session.
  Select all (Cmd+A) → Cmd+Enter

  After boot, talk to Claude to start making music.

*/

Server.default.options.sampleRate = 44100;
Server.default.options.maxLogins  = 2;
//Server.default.options.outDevice  = "BlackHole 2ch";
Server.killAll;

~cc = CC.boot(onComplete: {

    Routine {
        var modelDir = thisProcess.nowExecutingPath.dirname +/+ "models/";

        // ── Load RAVE models ──────────────────────────────────
        NN.load(\birds, modelDir ++ "birds.ts");
        s.sync;

        // ── Define RAVE SynthDefs ─────────────────────────────
        // SynthDefs are stored on scsynth and are visible to ALL clients,
        // including the CC MCP sclang. This means Claude Code + Claude Collider can use
        // \instrument, \rave_birds directly in Pbind — no bus routing
        // or Ndef needed.

        SynthDef(\rave_birds, {
            |out=0, freq=440, amp=0.5, gate=1, atk=0.01, rel=0.2, pan=0, gain=0.8|
            var sig       = SinOsc.ar(freq);
            var env       = EnvGen.kr(Env.asr(atk, 1, rel), gate, doneAction: 2);
            var processed = NN(\birds, \forward).ar(sig * amp * env, 2048);
            Out.ar(out, Pan2.ar(processed * gain, pan));
        }).add;

        s.sync;

        // ── Write marker file for Claude ──────────────────────
        File.use("/tmp/rave_synthdef.sc", "w", { |f|
            f.write("\"rave_synthdef boot confirmed\".postln;\n");
        });

        // ── Done ──────────────────────────────────────────────
        "════════════════════════════════════".postln;
        "  liveCoding-rave ready".postln;
        "  Model   : birds".postln;
        "  SynthDef: \\rave_birds".postln;
        "  Now talk to Claude.".postln;
        "════════════════════════════════════".postln;

    }.play;
});


/*
### Talk to Claude

With ClaudeCollider connected as an MCP server, open a conversation with Claude and start describing what you want:

> "Make a slow dark ambient texture using the birds model"

> "Play a Phrygian melody through birds"

> "Make a slow dark ambient texture with the birds model. Notes should be sparse and widely spaced, roughly 7 to 11 beats apart, with a short attack and a quick fade out. Keep the sound noisy and
  saturated. Add a slow kick, a sparse snare, and a dark bass underneath."

Claude uses \rave_birds directly as the Pbind instrument — no bus routing needed.
The SynthDef lives on scsynth and is available to Claude's sclang process automatically.

--
To debug:
s.queryAllNodes;      // check active nodes
s.sampleRate.postln;  // must be 44100 for RAVE to work

*/
