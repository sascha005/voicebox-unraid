# Kokoro TTS Server — Headless, CPU-only
# Ultra-slim: no PyTorch, no Transformers, just ONNX Runtime

FROM python:3.11-slim

# Install ffmpeg + curl
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install deps
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy server
COPY main.py .

# Create data dir
RUN mkdir -p /app/data/generations

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=60s \
    CMD curl -f http://localhost:17493/health || exit 1

EXPOSE 17493

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "17493"]
