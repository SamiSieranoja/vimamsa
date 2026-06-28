#!/usr/bin/env python3
"""Persistent faster-whisper transcription worker for the Vimamsa dictation module.

Loads the model once and stays alive, transcribing audio files on demand so that
repeated dictation is fast (no per-call model reload). The Ruby side
(modules/dictation/dictation.rb) spawns this, reads the readiness line, then feeds
one WAV path per line and reads one JSON response per line.

Protocol (line-based, JSON so transcripts with newlines stay one line):
  startup ->  {"ready": true}                      (model loaded)
          or  {"ready": false, "error": "..."}     (load/deps failed; then exits)
  stdin   <-  /path/to/audio.wav\\n                 (bare path), or
          <-  {"path": "...", "initial_prompt": "...", "beam_size": 1,
               "normalize": false, "vad": false}\\n  (per-request overrides)
  stdout  ->  {"ok": true,  "text": "..."}         (per request)
          or  {"ok": false, "error": "..."}

The transcription logic mirrors ~/Drive/util/bin/transcribe_audio.py (faster-whisper
+ ffmpeg level normalization + Silero VAD); it is kept self-contained here so the
editor does not depend on that personal script.

Requires: faster-whisper (pip install faster-whisper) and ffmpeg on PATH.
"""

import argparse
import json
import os
import subprocess
import sys
import tempfile
import threading
import time
from contextlib import contextmanager

# ffmpeg filter chain that evens out uneven speaker levels before ASR, so quiet
# speech isn't dropped by the VAD/decoder. Mirrors transcribe_audio.py.
NORMALIZE_FILTER = "afftdn=nr=12:nf=-25,dynaudnorm=f=150:g=7:p=0.9:m=25"


def _emit(obj):
    """Write one JSON object as a single flushed line on stdout."""
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


@contextmanager
def _normalized_audio(audio_path, normalize):
    """Yield a path to feed the decoder: the original file, or a normalized temp wav."""
    if not normalize:
        yield audio_path
        return
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=True) as tmp:
        cmd = ["ffmpeg", "-nostdin", "-v", "error", "-y", "-i", audio_path,
               "-ac", "1", "-ar", "16000", "-af", NORMALIZE_FILTER, tmp.name]
        subprocess.run(cmd, check=True)
        yield tmp.name


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--model", default="large-v3", help="faster-whisper model")
    ap.add_argument("--language", default="en", help="spoken language code")
    ap.add_argument("--device", default="auto", help="auto, cuda, or cpu")
    ap.add_argument("--compute-type", default="float16",
                    help="compute type, e.g. float16 or int8")
    ap.add_argument("--no-normalize", action="store_true",
                    help="skip ffmpeg level normalization (on by default)")
    ap.add_argument("--initial-prompt", default="",
                    help="text prompt that biases decoding toward a vocabulary/style")
    ap.add_argument("--beam-size", type=int, default=5, help="decoding beam size")
    ap.add_argument("--idle-timeout", type=float, default=300.0,
                    help="exit after this many seconds of inactivity to release "
                         "VRAM (<= 0 disables)")
    args = ap.parse_args()
    normalize = not args.no_normalize
    initial_prompt = args.initial_prompt or None

    # Load the model once. Report failure (missing deps, bad device, OOM) and exit.
    try:
        from faster_whisper import WhisperModel
        model = WhisperModel(args.model, device=args.device,
                             compute_type=args.compute_type)
    except Exception as e:  # noqa: BLE001 - report any startup failure to the client
        _emit({"ready": False, "error": f"{type(e).__name__}: {e}"})
        return 1

    # Exit the whole process after a period of inactivity so the model weights and
    # the CUDA context are fully released. `busy` keeps us alive mid-transcription
    # even if a long final pass exceeds the timeout. The Ruby side respawns us on
    # the next dictation.
    state = {"last": time.monotonic(), "busy": False}

    def _idle_watch(timeout):
        while True:
            time.sleep(min(max(timeout, 1.0), 15.0))
            if not state["busy"] and (time.monotonic() - state["last"]) > timeout:
                os._exit(0)

    if args.idle_timeout > 0:
        threading.Thread(target=_idle_watch, args=(args.idle_timeout,),
                         daemon=True).start()

    _emit({"ready": True})

    # One request per stdin line; one JSON response per line.
    # A request is either a bare WAV path, or a JSON object with per-request
    # overrides: {"path", "initial_prompt", "beam_size", "normalize", "vad"}.
    # The CLI args above supply the defaults (used for the preliminary passes,
    # which send fast overrides; the final pass sends high-quality overrides).
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        state["busy"] = True
        state["last"] = time.monotonic()
        try:
            if line.startswith("{"):
                req = json.loads(line)
                path = req["path"]
                req_prompt = req.get("initial_prompt", args.initial_prompt) or None
                req_beam = int(req.get("beam_size", args.beam_size))
                req_norm = bool(req.get("normalize", normalize))
                req_vad = bool(req.get("vad", True))
            else:
                path = line
                req_prompt, req_beam, req_norm, req_vad = (
                    initial_prompt, args.beam_size, normalize, True)

            with _normalized_audio(path, req_norm) as source:
                segments_iter, _info = model.transcribe(
                    source,
                    language=args.language,
                    vad_filter=req_vad,
                    beam_size=req_beam,
                    initial_prompt=req_prompt,
                )
                parts = [seg.text.strip() for seg in segments_iter if seg.text.strip()]
            _emit({"ok": True, "text": " ".join(parts)})
        except Exception as e:  # noqa: BLE001 - keep the worker alive across errors
            _emit({"ok": False, "error": f"{type(e).__name__}: {e}"})
        finally:
            state["last"] = time.monotonic()
            state["busy"] = False

    return 0


if __name__ == "__main__":
    sys.exit(main())
