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

# Download Kokoro model files at build time for instant startup
RUN mkdir -p /app/models && \
    curl -L -o /app/models/kokoro-v1.0.onnx \
        "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.int8.onnx" && \
    curl -L -o /app/models/voices-v1.0.bin \
        "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin"

# Copy server
COPY main.py .

# Create data dir
RUN mkdir -p /app/data/generations

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=60s \
    CMD curl -f http://localhost:17493/health || exit 1

EXPOSE 17493

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "17493"]
