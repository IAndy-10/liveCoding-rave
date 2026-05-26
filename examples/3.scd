/*
  RAVE Live Coding 3 — Microphone Input
  ══════════════════════════════════════
  Run each block with: select it → Cmd+Enter
  Stop all sound:      Cmd+.
  Recompile classes:   Cmd+Shift+L

  Models available:
    \birds  \marinemammals  \wheel

  Signal flow:
    Microphone → RAVE model → speakers
*/


// ════════════════════════════════════════════════════════
// BLOCK 1 — Boot server + load models
// Run once at the start of your session.
// ════════════════════════════════════════════════════════
(
s.options.memSize       = 65536;
s.options.numInputBusChannels  = 2;
s.options.numOutputBusChannels = 2;

s.waitForBoot {
    var modelDir = "/Users/italo/Desktop/Audio Programming Languages/liveCoding-rave/models/";

    NN.load(\birds,         modelDir ++ "birds.ts");
    NN.load(\marinemammals, modelDir ++ "marinemammals.ts");
    NN.load(\wheel,         modelDir ++ "wheel.ts");

    s.sync;

    [\birds, \marinemammals, \wheel].do { |m| NN(m).describe };

    "Ready. Microphone input on channel 0.".postln;
}
)


// ════════════════════════════════════════════════════════
// BLOCK 2 — Start RAVE processor with mic input
// Re-evaluate any line below to switch model live.
// ════════════════════════════════════════════════════════
(
Ndef(\rave, {
    var in  = SoundIn.ar(0);             // microphone input
    var out = NN(\birds, \forward).ar(in, 2048);  // ← change model here
    out = out ! 2;                       // mono → stereo
    out * \gain.kr(0.8)
}).play;
)

// Switch model — select a line and Cmd+Enter:
Ndef(\rave, { var in = SoundIn.ar(0); (NN(\birds,         \forward).ar(in, 2048) ! 2) * \gain.kr(0.8) }).play;
Ndef(\rave, { var in = SoundIn.ar(0); (NN(\marinemammals, \forward).ar(in, 2048) ! 2) * \gain.kr(0.8) }).play;
Ndef(\rave, { var in = SoundIn.ar(0); (NN(\wheel,         \forward).ar(in, 2048) ! 2) * \gain.kr(0.8) }).play;


// ════════════════════════════════════════════════════════
// CONTROLS
// ════════════════════════════════════════════════════════

// Adjust output gain (0.0 - 1.0)
Ndef(\rave).set(\gain, 0.8);

// Dry/wet — blend mic and RAVE output
Ndef(\rave, {
    var in   = SoundIn.ar(0);
    var rave = NN(\birds, \forward).ar(in, 2048) ! 2;
    var dry  = in ! 2;
    ((dry * (1 - \mix.kr(1))) + (rave * \mix.kr(1))) * \gain.kr(0.8)
}).play;

Ndef(\rave).set(\mix, 1.0);  // 0 = dry mic, 1 = full RAVE
Ndef(\rave).set(\mix, 0.5);  // 50/50 blend

// Stop
Ndef(\rave).stop;
