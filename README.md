# Voicebox Unraid — Local TTS Server (Headless/API-Only)

Fork/Build von [jamiepine/voicebox](https://github.com/jamiepine/voicebox) für Unraid.

Stripped-down Version: **nur API-Server**, keine Desktop-GUI. Für Hermes-Agent Voice Messages und Automationen.

## Was ist Voicebox?

- **Local-first AI TTS** — Open-Source Alternative zu ElevenLabs
- **Voice Cloning** — Eigene Stimmen klonen
- **7 TTS Engines** — Kokoro (82M, CPU-schnell), LuxTTS, Qwen3-TTS, etc.
- **REST API** — `POST /generate`, `GET /audio/{id}`
- **Keine GPU nötig** — Kokoro läuft schnell auf CPU

## Deployment

### Unraid (empfohlen)

1. CA (Community Applications) → Suche nach "Voicebox"
2. Oder: Template manuell hinzufügen
3. Port 17493 mappen
4. Data-Pfad persistent mounten

### Docker (manuell)

```bash
docker run -d \
  --name voicebox \
  -p 17493:17493 \
  -v /mnt/user/appdata/voicebox:/app/data \
  ghcr.io/sascha005/voicebox-unraid:latest
```

### Build (lokal)

```bash
git clone https://github.com/sascha005/voicebox-unraid.git
cd voicebox-unraid
docker build -t voicebox-unraid:local .
```

## API-Usage

### Server-Status
```bash
curl http://localhost:17493/health
```

### TTS generieren
```bash
curl -X POST http://localhost:17493/generate \
  -H "Content-Type: application/json" \
  -d '{"text": "Hallo Sascha", "profile_id": "default"}'
```

### Audio herunterladen
```bash
curl http://localhost:17493/audio/{generation_id} -o output.wav
```

## Hermes-Integration

Siehe `vault/Smart-Home/Voicebox-TTS-Integration.md`

## Referenzen

- Original: https://github.com/jamiepine/voicebox
- Docs: https://docs.voicebox.sh
- API: https://github.com/jamiepine/voicebox/blob/main/app/src/lib/api/services/DefaultService.ts
