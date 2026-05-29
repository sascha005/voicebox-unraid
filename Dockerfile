# Voicebox Unraid — Headless TTS Server
# Based on: https://github.com/jamiepine/voicebox
# Stripped for Unraid: API-only, no Desktop GUI

FROM python:3.11-slim

# Install build deps + git + ffmpeg
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    build-essential \
    ffmpeg \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Clone voicebox repo (shallow, depth 1)
RUN git clone --depth 1 https://github.com/jamiepine/voicebox.git /voicebox-src

# Create app directory
WORKDIR /app

# Copy backend code
RUN cp -r /voicebox-src/backend/* /app/ && \
    rm -rf /voicebox-src

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip
RUN pip install --no-cache-dir -r /app/requirements.txt

# Install extra backends (Kokoro, etc.)
RUN pip install --no-cache-dir \
    kokoro-onnx \
    soundfile

# Create non-root user
RUN groupadd -r voicebox && \
    useradd -r -g voicebox -m -s /bin/bash voicebox

# Create data directories
RUN mkdir -p /app/data/generations /app/data/profiles /app/data/cache /app/data/models && \
    chown -R voicebox:voicebox /app/data

# Pre-download Kokoro model (small, ~82M, voicebox default)
# This speeds up first-run; can be skipped with env var
ENV PRELOAD_MODELS=true
RUN if [ "$PRELOAD_MODELS" = "true" ]; then \
        python3 -c "from kokoro_onnx import Kokoro; k = Kokoro()" || true; \
    fi

USER voicebox

# Expose API port
EXPOSE 17493

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=60s \
    CMD curl -f http://localhost:17493/health || exit 1

# Start FastAPI server
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "17493"]
