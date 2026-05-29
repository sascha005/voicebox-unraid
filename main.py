#!/usr/bin/env python3
"""Minimal headless TTS server using Kokoro-ONNX.
No PyTorch, no Transformers — just ONNX Runtime (~100MB model).
Drop-in replacement for voicebox backend: /health + /generate endpoints.
"""

import os
import json
import uuid
import hashlib
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field
import soundfile as sf

# ── Config ──────────────────────────────────────────────
PORT = int(os.getenv("TTS_PORT", "17493"))
DATA_DIR = Path(os.getenv("TTS_DATA_DIR", "/app/data"))
GEN_DIR = DATA_DIR / "generations"
GEN_DIR.mkdir(parents=True, exist_ok=True)

# Optional: default voice
DEFAULT_VOICE = os.getenv("TTS_DEFAULT_VOICE", "af_bella")

# ── Kokoro Setup ────────────────────────────────────────
# kokoro-onnx will auto-download model/voices on first call (~100 MB)
from kokoro_onnx import Kokoro
_tts = None

def _get_tts():
    global _tts
    if _tts is None:
        _tts = Kokoro()
    return _tts

# ── FastAPI ─────────────────────────────────────────────
app = FastAPI(title="Kokoro TTS Server", version="1.0.0")

class GenerateRequest(BaseModel):
    text: str = Field(..., description="Text to synthesise", max_length=5000)
    voice: Optional[str] = Field(DEFAULT_VOICE, description="Voice ID, e.g. am_adam, af_bella")
    speed: float = Field(1.0, ge=0.5, le=2.0, description="Speech speed factor")
    response_format: str = Field("wav", description="Audio format: wav, mp3, ogg, opus")

class GenerationResponse(BaseModel):
    generation_id: str
    audio_url: str
    duration_seconds: float
    voice: str
    text: str

# ── Endpoints ─────────────────────────────────────────────

@app.get("/health")
def health():
    return {"status": "ok", "engine": "kokoro-onnx", "data_dir": str(DATA_DIR)}

@app.get("/voices")
def voices():
    # kokoro provides these voices out-of-the-box
    return {
        "voices": [
            {"id": "af_bella",  "name": "Bella",  "lang": "en-US", "gender": "F"},
            {"id": "af_nicole", "name": "Nicole", "lang": "en-US", "gender": "F"},
            {"id": "af_sarah",  "name": "Sarah",  "lang": "en-US", "gender": "F"},
            {"id": "am_adam",   "name": "Adam",   "lang": "en-US", "gender": "M"},
            {"id": "am_michael","name": "Michael","lang": "en-US", "gender": "M"},
            {"id": "bf_emma",   "name": "Emma",   "lang": "en-GB", "gender": "F"},
            {"id": "bm_george", "name": "George", "lang": "en-GB", "gender": "M"},
        ]
    }

@app.post("/generate", response_model=GenerationResponse)
def generate(req: GenerateRequest, background: BackgroundTasks):
    if not req.text.strip():
        raise HTTPException(400, "text is empty")

    tts = _get_tts()
    gen_id = str(uuid.uuid4())
    tmp_wav = GEN_DIR / f"{gen_id}.wav"
    out_path = GEN_DIR / f"{gen_id}.{req.response_format}"

    try:
        # 1. synthesise with kokoro
        samples, sample_rate = tts.generate(req.text, voice=req.voice, speed=req.speed)
        sf.write(str(tmp_wav), samples, sample_rate)

        # 2. transcode if needed
        if req.response_format == "wav":
            tmp_wav.rename(out_path)
        else:
            _transcode(tmp_wav, out_path, req.response_format)
            tmp_wav.unlink(missing_ok=True)

        # 3. duration
        info = sf.info(str(out_path))
        duration = info.duration

    except Exception as exc:
        tmp_wav.unlink(missing_ok=True)
        out_path.unlink(missing_ok=True)
        raise HTTPException(500, f"generation failed: {exc}")

    return GenerationResponse(
        generation_id=gen_id,
        audio_url=f"/audio/{gen_id}.{req.response_format}",
        duration_seconds=duration,
        voice=req.voice,
        text=req.text,
    )

@app.get("/audio/{generation_id}")
def get_audio(generation_id: str):
    # try all known extensions
    for ext in ("wav", "mp3", "ogg", "opus"):
        p = GEN_DIR / f"{generation_id}.{ext}"
        if p.exists():
            return FileResponse(p, media_type=_mime(ext))
    raise HTTPException(404, "audio not found")

# ── Helpers ─────────────────────────────────────────────

def _mime(ext: str) -> str:
    return {
        "wav":  "audio/wav",
        "mp3":  "audio/mpeg",
        "ogg":  "audio/ogg",
        "opus": "audio/opus",
    }.get(ext, "application/octet-stream")

def _transcode(src: Path, dst: Path, fmt: str):
    import subprocess
    codec = {
        "mp3":  ("libmp3lame", "-q:a", "4"),
        "ogg":  ("libopus", "-b:a", "96k"),
        "opus": ("libopus", "-b:a", "96k"),
    }[fmt]
    cmd = [
        "ffmpeg", "-y", "-i", str(src),
        "-c:a", codec[0], *codec[1:],
        "-threads", "2",
        str(dst),
    ]
    subprocess.run(cmd, check=True, capture_output=True)

# ── Entry point ─────────────────────────────────────────
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=PORT, reload=False)
