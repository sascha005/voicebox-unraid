# ============================================================
# Voicebox — Full Backend with Voice Cloning (Qwen3-TTS, LuxTTS)
# Headless for Unraid: no Desktop GUI, API-only
# Clones voicebox repo at build time
# ============================================================

FROM python:3.11-slim

WORKDIR /voicebox-src

# Install build + runtime deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    build-essential \
    ffmpeg \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Clone voicebox (shallow)
RUN git clone --depth 1 https://github.com/jamiepine/voicebox.git /voicebox-src

WORKDIR /app

# Install Python deps — piper-phonemize needs custom index first
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir \
        --find-links https://k2-fsa.github.io/icefall/piper_phonemize.html \
        piper-phonemize && \
    pip install --no-cache-dir -r /voicebox-src/backend/requirements.txt && \
    pip install --no-cache-dir --no-deps chatterbox-tts && \
    pip install --no-cache-dir --no-deps hume-tada && \
    pip install --no-cache-dir git+https://github.com/QwenLM/Qwen3-TTS.git

# Copy backend code (preserve backend/ as a Python module)
RUN cp -r /voicebox-src/backend /app/backend && rm -rf /voicebox-src

# Create non-root user
RUN groupadd -r voicebox && \
    useradd -r -g voicebox -m -s /bin/bash voicebox \
    && mkdir -p /app/data/generations /app/data/profiles /app/data/cache /app/data/models \
    && chown -R voicebox:voicebox /app/data

EXPOSE 17493

CMD ["uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "17493"]
