# Companion PC (not in this repository)

`thinksmart-flash` is flash notes plus the panel kiosk. The always-on Linux box on the LAN runs two other programs. Clone and run them next to this tree; do not expect them under `kiosk/`.

| Program | Bind | Role |
| --- | --- | --- |
| `voice-assistant` | HTTPS `:8765` | Grok Voice S2S, STT, optional HA tools |
| Bloub Node streamer | HTTP `:8766` | Cream Grok-bot JPEGs (`sharp`, ~12 fps) |

UFW: allow `8765/tcp` and `8766/tcp` from `LAN_CIDR` only. Do not publish them. The panel uses `curl -sk` (unverified companion TLS) and WebKit with sandbox off; keep those ports LAN-only.

Set `VOICE_HOST` and `FACE_HOST` in `kiosk/kiosk.env` to that box's IPv4. Never put `XAI_API_KEY` in `kiosk.env`.

## voice-assistant

The panel uses `curl -sk`. Put `XAI_API_KEY` in a `0600` `.env` on the companion.

| Method | Path | Body | Response |
| --- | --- | --- | --- |
| `GET` | `/api/health` | | `kitchen_backend=voice`, `voice=grok-voice-latest`, `voice_name=eve` |
| `POST` | `/api/turn` | multipart `audio=@clip.wav` (16 kHz mono PCM WAV), `reasoning=false` | JSON `transcript`, `reply`, `audio_b64` (24 kHz WAV) |
| `POST` | `/api/transcribe` | multipart `audio=@wake.wav` | JSON `transcript` |
| `POST` | `/api/reset` | empty | drop the Voice session |

HA stays on the LAN: the companion implements `ha_turn_on` / `ha_turn_off` / `ha_status` and talks to `http://HA_HOST:8123/api/mcp`. Do not put that MCP URL in Voice `type: mcp`.

Typical start:

```bash
cd /path/to/voice-assistant
# .env mode 0600: XAI_API_KEY, VOICE_KITCHEN_BACKEND=voice
.venv/bin/python -m voice_assistant start
curl -sk https://127.0.0.1:8765/api/health
```

## Bloub streamer

Bind the LAN NIC only (`BLOUB_BIND` / `BLOUB_PORT`, default `:8766`).

| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/face.jpg` | one baseline JPEG |
| `GET` | `/face.mjpeg` | multipart; WebKitGTK 6 on the panel does not paint this in `<img>` |
| `GET` or `POST` | `/face?name=` | pose: idle, wide, thinking, notify, alert, sleep |
| `GET` | `/health` | liveness |

The panel never opens `:8766` from WebKit. `thinksmart-face.py` proxies `GET /bot.jpg` (one JPEG per poll). JPEG stills in `kiosk/faces/` are the on-glass fallback when the streamer is down.

Face map from kiosk state: idle→idle, listen→wide, thinking→thinking, speak→notify, error→alert, sleep→sleep.

Colors: body `#eceae6`, paper `#1a1a1a`, ~720 px, 12 fps.

Engine: [jeremy-prt/bloub](https://github.com/jeremy-prt/bloub) (MIT code, not affiliated with xAI).
