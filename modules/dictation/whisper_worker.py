#!/usr/bin/env python3
"""Persistent faster-whisper transcription worker for the Vimamsa dictation module.

Loads the model once and stays alive, transcribing audio files on demand so that
repeated dictation is fast (no per-call model reload). The Ruby side
(modules/dictation/dictation.rb) spawns this, reads the readiness line, then feeds
one WAV path per line and reads one JSON response per line.

Protocol (line-based, JSON so transcripts with newlines stay one line):
  startup ->  {"ready": true}                      (model loaded)
          or  {"ready": false, "error": "..."}     (load/deps failed; then exits)
  stdin   <-  /path/to/audio.wav\\n                 (one request)
  stdout  ->  {"ok": true,  "text": "..."}         (per request)
          or  {"ok": false, "error": "..."}

The transcription logic mirrors ~/Drive/util/bin/transcribe_audio.py (faster-whisper
+ ffmpeg level normalization + Silero VAD); it is kept self-contained here so the
editor does not depend on that personal script.

Requires: faster-whisper (pip install faster-whisper) and ffmpeg on PATH.
"""

import argparse
import json
import subprocess
import sys
import tempfile
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
    ap.add_argument("--beam-size", type=int, default=5, help="decoding beam size")
    args = ap.parse_args()
    normalize = not args.no_normalize

    # Load the model once. Report failure (missing deps, bad device, OOM) and exit.
    try:
        from faster_whisper import WhisperModel
        model = WhisperModel(args.model, device=args.device,
                             compute_type=args.compute_type)
    except Exception as e:  # noqa: BLE001 - report any startup failure to the client
        _emit({"ready": False, "error": f"{type(e).__name__}: {e}"})
        return 1

    _emit({"ready": True})

    # One WAV path per stdin line; one JSON response per line.
    for line in sys.stdin:
        path = line.strip()
        if not path:
            continue
        try:
            with _normalized_audio(path, normalize) as source:
                segments_iter, _info = model.transcribe(
                    source,
                    language=args.language,
                    vad_filter=True,
                    beam_size=args.beam_size,
                )
                parts = [seg.text.strip() for seg in segments_iter if seg.text.strip()]
            _emit({"ok": True, "text": " ".join(parts)})
        except Exception as e:  # noqa: BLE001 - keep the worker alive across errors
            _emit({"ok": False, "error": f"{type(e).__name__}: {e}"})

    return 0


if __name__ == "__main__":
    sys.exit(main())
