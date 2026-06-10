"""
NeoChucao — server.py
Boots scsynth via supriya, loads the RAVE model, loads the SynthDef.

Note: supriya's add_synth() requires a SynthDef object it compiled itself.
Since rave_decoder.scsyndef contains external UGens (NNUGen) unknown to supriya,
we use raw OSC (/s_new, /n_set, /n_free) instead — the same wire protocol
add_synth uses internally.

FX chain:
  rave_decoder nodes → private stereo bus (FX_BUS_ID)
                     → neochucao_fx synth (reverb, compiled by supriya)
                     → hardware output bus 0
  Adjust at runtime with set_fx(mix=..., room_size=..., damping=...).
"""

import itertools
import subprocess
import tempfile
import time
from pathlib import Path

import supriya
from supriya.osc import OscMessage

SCSYNTH       = "/Applications/SuperCollider.app/Contents/Resources/scsynth"
MODELS_DIR    = Path(__file__).parent.parent / "models"
SYNTHDEFS_DIR = Path(__file__).parent.parent / "synthdefs"

# Model index baked into rave_decoder.scsyndef at compile time.
# Must match the id used when the SynthDef was compiled in SC (first model = 0).
MODEL_IDX = 0 # 0 is the birds.ts model, 1 would be the drums.ts model

# First private stereo audio bus (buses 0–1 = hardware out, input disabled).
FX_BUS_ID = 2

server: supriya.Server | None = None
_node_id_counter = itertools.count(1000)  # scsynth node IDs start after reserved range
_fx_node_id: int | None = None            # node ID of the running FX synth


class RawSynth:
    """Thin wrapper around a scsynth node — mirrors the supriya Synth interface."""

    def __init__(self, node_id: int):
        self.node_id = node_id

    def set(self, **params) -> None:
        args = []
        for k, v in params.items():
            args += [k, float(v)]
        server.send(OscMessage("/n_set", self.node_id, *args))

    def free(self) -> None:
        server.send(OscMessage("/n_free", self.node_id))


def add_synth(name: str = "rave_decoder", **params) -> RawSynth:
    """Create a new synth node on the default group (node 1), routed into the FX bus."""
    node_id = next(_node_id_counter)
    # /s_new defName nodeID addAction targetID [ctrlName value ...]
    # addAction 0 = ADD_TO_HEAD, targetID 1 = default group
    params.setdefault("out", FX_BUS_ID)
    args = [name, node_id, 0, 1]
    for k, v in params.items():
        args += [k, float(v)]
    server.send(OscMessage("/s_new", *args))
    return RawSynth(node_id)


def _boot_fx_chain() -> None:
    """Compile and start the FX synth at the tail of the default group.

    Uses only standard SC UGens — supriya compiles this directly without a
    pre-baked .scsyndef file. The FX synth reads from FX_BUS_ID (where
    rave_decoder nodes write) and outputs to hardware bus 0.

    FreeVerb.ar multichannel-expands over the stereo input automatically.
    """
    global _fx_node_id

    with supriya.SynthDefBuilder(
        in_bus=float(FX_BUS_ID),
        out_bus=0.0,
        mix=0.25,
        room_size=0.6,
        damping=0.5,
    ) as builder:
        source = supriya.ugens.In.ar(bus=builder["in_bus"], channel_count=2)
        # FreeVerb multichannel-expands over the 2-channel source → stereo reverb
        reverbed = supriya.ugens.FreeVerb.ar(
            source=source,
            mix=builder["mix"],
            room_size=builder["room_size"],
            damping=builder["damping"],
        )
        supriya.ugens.Out.ar(bus=builder["out_bus"], source=reverbed)

    fx_synthdef = builder.build(name="neochucao_fx")
    server.add_synthdefs(fx_synthdef)
    server.sync()
    print("[server] neochucao_fx SynthDef compiled and sent")

    # Start at TAIL of default group so it runs after all rave_decoder nodes.
    # addAction 1 = ADD_TO_TAIL, targetID 1 = default group
    _fx_node_id = next(_node_id_counter)
    server.send(OscMessage("/s_new", "neochucao_fx", _fx_node_id, 1, 1))
    print(f"[server] FX chain running — bus {FX_BUS_ID} → reverb → out 0")


def set_fx(**params) -> None:
    """Adjust FX parameters at runtime.

    Recognised keys: mix (0–1), room_size (0–1), damping (0–1).
    Example: server.set_fx(mix=0.4, room_size=0.8)
    """
    if _fx_node_id is None:
        return
    args = []
    for k, v in params.items():
        args += [k, float(v)]
    server.send(OscMessage("/n_set", _fx_node_id, *args))


def boot(output_device: str | None = None) -> supriya.Server:
    global server

    # ── 1. Boot scsynth ──────────────────────────────────────────────────────
    # Kill any stale scsynth process left over from a previous crashed session.
    subprocess.run(["pkill", "-x", "scsynth"], check=False)
    time.sleep(0.5)

    server = supriya.Server()
    boot_kwargs: dict = dict(
        executable=SCSYNTH,
        input_bus_channel_count=0,      # disable mic input (avoids sample-rate mismatch)
        memory_size=65536,
    )
    if output_device:
        boot_kwargs["output_device"] = output_device
    server.boot(**boot_kwargs)
    print("[server] scsynth booted")

    # ── 2. Load RAVE model via raw OSC ───────────────────────────────────────
    # nn.ar OSC format (from NN.sc line 82):
    #   /cmd  "/nn_load"  modelIdx  modelPath  infoFilePath
    # scsynth loads the model and writes a YAML info file to infoFilePath.
    model_path = str((MODELS_DIR / "birds.ts").resolve()) #If changed, also change MODEL_IDX if necessary
    with tempfile.NamedTemporaryFile(suffix=".yaml", delete=False) as f:
        info_path = f.name

    server.send(
        OscMessage("/cmd", "/nn_load", MODEL_IDX, model_path, info_path)
    )
    server.sync()

    if not Path(info_path).exists():
        raise RuntimeError(
            f"[server] nn.ar model load failed — info file not written.\n"
            f"  model: {model_path}\n"
            f"  Make sure nn.ar is installed in SC Extensions."
        )
    print(f"[server] birds.ts loaded at model index {MODEL_IDX}")

    # ── 3. Load SynthDef ─────────────────────────────────────────────────────
    synthdef_path = str((SYNTHDEFS_DIR / "rave_decoder.scsyndef").resolve())
    server.load_synthdefs(synthdef_path)
    server.sync()
    print("[server] rave_decoder SynthDef loaded")

    # ── 4. Compile + start FX chain ──────────────────────────────────────────
    _boot_fx_chain()

    return server


def quit() -> None:
    global server, _fx_node_id
    if server is not None:
        server.quit()
        server = None
        _fx_node_id = None
        print("[server] scsynth stopped")


# ── Smoke test ────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    srv = boot()

    print("[test] triggering test synth (z0=1.2, z1=-0.8, z2=0.5) …")
    synth = add_synth("rave_decoder", z0=1.2, z1=-0.8, z2=0.5, amp=0.4)
    time.sleep(3)
    synth.set(gate=0)   # trigger ADSR release
    time.sleep(1)

    quit()
