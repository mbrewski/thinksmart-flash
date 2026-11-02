# ThinkSmart Grok voice kiosk

Turn a Lenovo **ThinkSmart View (CD-18781Y)** into a wall-mounted English Grok voice panel: hold-to-talk or “hey grok,” Eve speech-to-speech, optional Home Assistant, and a streamed Grok-bot face.

This tree is **flash notes plus the panel kiosk**: hybrid 6.12 Ubuntu, cage UI, TAS speaker route, WirePlumber overlay, SSH deploy. It is not the stock Plasma Mobile desktop and not [justhalfbit/thinksmart-ubuntu-image](https://github.com/justhalfbit/thinksmart-ubuntu-image). Those matter only as flash sources or alternatives (see [Other images](#other-images)).

`voice-assistant` and the Bloub Node streamer run on a companion PC and **are not in this repository**. Panel HTTP contracts for those two programs are in [`companion/README.md`](companion/README.md).

```
 ThinkSmart 800×1280              Companion PC (LAN)                 Cloud / house
 ┌─────────────────────────┐      ┌──────────────────────────┐      ┌─────────────┐
 │ cage + GTK4/WebKit      │      │ voice-assistant :8765    │      │ grok-voice  │
 │ thinksmart-face.py      │ WAV  │  Grok Voice S2S (Eve)    │ WSS  │  -latest    │
 │ 127.0.0.1:1680          ├─────►│  web_search, optional    ├─────►│             │
 │ hold / hey grok         │      │  Tavily + HA functions   │      └─────────────┘
 │ pw-play TAS 48 kHz      │◄─────┤                          │
 │ img /bot.jpg            │      └────────────┬─────────────┘      ┌─────────────┐
 └──────────▲──────────────┘                   │ LAN only           │ Home        │
            │ MJPEG proxy                      ▼                    │ Assistant   │
            │                     bloub-stream :8766                │ :8123/mcp   │
            └──────────────────── Node + sharp, 12 fps ─────────────┴─────────────┘
```

The panel is too small (2 GB RAM, 8 GB eMMC) to run Grok Voice or the Bloub engine locally. A always-on Linux box on the same LAN does both.

GitHub does **not** ship flash images, your Android dump, or secrets. Clone this repo, then add those locally (see [Installation](#installation)).

---

## Configure before you copy files

Set these in `kiosk/kiosk.env` (copy `kiosk/kiosk.env.example`) or `/etc/thinksmart-kiosk.env`, mode `0600`. The face and wake scripts load that file. Keep it out of git.

| Variable | Meaning | Where it is used |
| --- | --- | --- |
| `VOICE_HOST` | Companion PC IPv4 | `TURN_URL`, `RESET_URL`, `STT_URL` |
| `FACE_HOST` | Same box, or another LAN host that runs the streamer | `FACE_STREAM` |
| `CLOCK_TZ` | IANA timezone for the on-glass clock | `/state` → kiosk JS |
| `HA_HOST` | Home Assistant, optional | companion `ha.env` / HA MCP client |
| `LAN_CIDR` | e.g. `192.168.1.0/24` | UFW on the companion |
| `SSID` / `PSK` | Wi-Fi | `secrets/wifi.env` mode `0600` |
| `XAI_API_KEY` | xAI key | companion `.env` mode `0600` |

```bash
cp kiosk/kiosk.env.example kiosk/kiosk.env
# edit VOICE_HOST, FACE_HOST, CLOCK_TZ
chmod 600 kiosk/kiosk.env
cp secrets/wifi.env.example secrets/wifi.env
chmod 600 secrets/wifi.env
```

Do not publish `:8765`, `:8766`, Home Assistant, or leftover 小智 ports `16688`/`16689` to the internet.

---

## Contents

1. [What you get](#what-you-get)
2. [Hardware requirements](#hardware-requirements)
3. [Software requirements](#software-requirements)
4. [Ubuntu image bug fixes](#ubuntu-image-bug-fixes)
5. [Installation](#installation)
6. [Bloub library](#bloub-library)
7. [Daily use](#daily-use)
8. [Operations](#operations)
9. [Other images](#other-images)
10. [Credits](#credits)

On-disk layout that GitHub ships: `README.md`, `kiosk/` (UI, audio route, overlay, `install-panel.sh`), `tools/edl.sh`, `tools/deploy-kiosk.sh`, `tools/loaders/`, `companion/README.md`, `repair-ubuntu-boot.sh`, `wait-edl.py`. Flash images, `dump/`, `tools/edl`, and `tools/edl-venv` stay local.

---

## What you get

On the glass:

- Full-screen **cage** compositor (Plasma is dropped to free RAM).
- Cream Grok-bot face streamed as MJPEG from the companion PC ([jeremy-prt/bloub](https://github.com/jeremy-prt/bloub), MIT code, not affiliated with xAI).
- Clock at the top, short hint at the bottom.
- Hold-to-talk anywhere on the panel, or say **hey grok** / **ok grok**.
- After Eve finishes speaking, a **15 second** “I’m listening” window so you can keep talking without a new wake.
- Hardware mic slider left → Bloub **sleep** pose and hint “mic muted”.

On the companion PC (separate trees; see [`companion/README.md`](companion/README.md)):

- HTTPS `voice-assistant` on `:8765`.
- `POST /api/turn` runs **Grok Voice** (`grok-voice-latest`, voice Eve): 16 kHz PCM in, 24 kHz WAV out.
- Tools: native `web_search`, optional Tavily MCP, optional **local** Home Assistant functions (`ha_turn_on`, `ha_turn_off`, `ha_status`) so HA stays on the LAN.
- Node + `sharp` Bloub streamer on `:8766`.

---

## Hardware requirements

### Panel (required)

| | |
| --- | --- |
| Device | Lenovo ThinkSmart View **CD-18781Y** only |
| SoC | Qualcomm APQ8053 / MSM8953 |
| RAM / eMMC | 2 GB LPDDR3 / 8 GB (`8GTF4R`, 15269888 × 512-byte blocks) |
| Display | 8-inch portrait IPS DSI, **800×1280**. Many units are **Himax HX83100A** (`panel_lenovo_cd_18781y_hx83100a`). Other CD-18781Y panels exist; a 6.19 kernel that works on those can still black a Himax glass. |
| Audio | TI **TAS5782M** Class-D on I2C `1-0049`, I2S QUAT_MI2S. PCM `hw:cd18781y,0` is **S16_LE stereo 48 kHz**. |
| Mics | Dual DMIC. Top-edge **slider left = hardware mute**; PipeWire cannot override it. |
| Radios | QCA9379 SDIO Wi-Fi/BT (`ath10k_sdio`). No cellular. |
| USB-C | Gadget by default, **no OTG ID**, does not drive 5 V VBUS. Debug/EDL on the **bottom** USB-C. |
| Bootloader | OEM **locked**. Fastboot cannot flash unsigned images. Qualcomm EDL (`05c6:9008`) is the only write path. |

Confirm in EDL: `edl printgpt` reports CPU `APQ8053` and `total_blocks:15269888`. If either differs, stop.

### Flash host

- macOS or Linux with a **data-capable** cable.
- USB **2.0** port or hub port. USB 3, USB-C-to-C, and charge-only cables often fail Sahara.
- A cheap USB 2 hub is often more reliable than a USB 3 port on the host.

### Companion PC (required)

- Always-on Linux on the same LAN as the panel (x86_64 is what this tree was built against).
- Outbound HTTPS/WSS to `api.x.ai`.
- Optional: reaches Home Assistant on the LAN.
- No GPU required for Voice S2S (xAI runs the model).

### Home Assistant (optional)

- Home Assistant OS with MCP at `http://HA_HOST:8123/api/mcp`.
- A local user that can log in. Store username/password in a `0600` file on the companion, not in git.

---

## Software requirements

### Flash host

| Piece | Why |
| --- | --- |
| [bkerler/edl](https://github.com/bkerler/edl) | Sahara/Firehose. `./tools/edl.sh` clones it to `tools/edl/` and builds `tools/edl-venv` on first run. |
| Firehose loader | `tools/edl/Loaders/lenovo_motorola/000660e160008000_b9eca30dfea46934_fhprg_peek.bin` (HWID `0x000660e160008000`). |
| [rickx/ubuntu-thinksmart](https://github.com/rickx/ubuntu-thinksmart) | Ubuntu 24.04 port, `FLASHING.md`, `prebuilt/lk2nd.img`, bootstrap scripts. Clone beside this repo if you need `apply-ubuntu-gpt.sh`. |
| Images | Rickx bootstrap and Plasma 6 Ubuntu MEGA image, renamed here to `images/thinksmart-flash-bootstrap.img` and `images/thinksmart-flash.img` (~6.8 GiB). |
| e2fsprogs `debugfs` | Splice kernels/DTB into ext2 `pmOS_boot`. |
| Python 3 | Deploy kiosk files over SSH. The rickx image defaults to password login (`ubuntu` / `thinksmart`); change it. |

You do **not** need fastboot flashing, Magisk, QFIL (except as a last-resort stock restore), or Android Studio.

### Companion PC

| Piece | Why |
| --- | --- |
| `voice-assistant` | FastAPI HTTPS `:8765`. **Not in this repo.** |
| Python venv | `httpx`, `websockets`, `numpy`, `soundfile`, Kokoro fallback TTS. |
| `XAI_API_KEY` | `0600` `.env`. Never in git or this README. |
| Tavily key | Optional; Voice also has native `web_search`. |
| Node.js 22 + `sharp` | Bloub JPEG/MJPEG streamer on `:8766`. **Not in this repo.** |
| UFW (or equivalent) | Allow `:8765` and `:8766` from `LAN_CIDR` only. |

### Panel (after Ubuntu is up)

| Piece | Why |
| --- | --- |
| Kernel | **pmOS 6.12.0-postmarketos-qcom-msm8953** + Himax DTB `apq8053-lenovo-cd-18781y.dtb`. |
| Userspace | Ubuntu 24.04 root (the rickx Plasma 6 image). |
| cage | Tiny Wayland compositor. SDDM autologin running `thinksmart-face.py`. |
| GTK 4 + WebKitGTK 6 | `libwebkitgtk-6.0`. Chromium snap is too big for a ~6.4 G root. |
| PipeWire + WirePlumber | TAS sink `alsa_output.platform-c051000.sound-card.HiFi__Speaker__sink`. |
| `pw-record` / `pw-play` / `paplay` / `amixer` | Capture 48 kHz s32, play 48 kHz s16. |
| Python 3 (system) | `thinksmart-face.py` (Gtk) and `thinksmart-wake.py`. Optional venv site-packages only for Sherpa KWS. |

**Do not `apt full-upgrade`.** It has stripped Plasma/WebKit/PipeWire mixes on neon leftovers.

Default accounts after flash: `ubuntu` / `thinksmart` (passwordless sudo) and, on bootstrap, `pmos` / `thinksmart`. Change both.

---

## Ubuntu image bug fixes

The public rickx Plasma 6 image is a bring-up, not a kiosk. A Himax CD-18781Y needs the following. **Do not `apt full-upgrade`.** **Do not enable Plasma DPMS timeouts on DSI.**

### 1. Empty `pmOS_boot` (upstream)

The MEGA Plasma 6 image (`thinksmart-flash.img` in this tree) has been seen with an empty boot payload (rickx issue #3). lk2nd then drops to Fastboot.

**Fix:** `repair-ubuntu-boot.sh` copies vmlinuz, initramfs, extlinux, and DTB from the bootstrap `pmOS_boot` into partition 1 of the Ubuntu image before EDL.

### 2. Himax panel vs kernel 6.19.5

Stock Ubuntu/pmOS **6.19.5** plus the Himax DTB still **black-screens after lk2nd** on Himax glass. Working DRM is msm on `card0-DSI-1`, framebuffer `msmdrmfb`, backlight `/sys/class/backlight/backlight` (max 4095).

**Fix:** hybrid image — keep **6.12.0-postmarketos-qcom-msm8953** and the Himax DTB on `pmOS_boot`, Ubuntu 24.04 on `pmOS_root`, inject matching 6.12 modules into the rootfs. Artifacts in this tree:

- `work/thinksmart-flash-boot-612.img` / `work/thinksmart-flash-boot-612-mask.img` (p1)
- `work/pmos-mods/` (6.12 modules to inject into the Ubuntu root)
- DTB in extlinux: `/apq8053-lenovo-cd-18781y.dtb`
- Partition UUIDs are those of the **rickx Plasma 6 image**, not a unique serial. Copy them from `work/thinksmart-flash-extlinux.conf` (`pmos_boot_uuid`, `pmos_root_uuid`) when you splice extlinux.

justhalfbit’s public image still ships **unchanged 6.19.5**. Do not flash it onto a Himax unit unless you have confirmed that kernel lights the panel.

### 3. Boot SError from `devmem` audio/i2c scripts

`pmos-audio-route.service` and `i2c1-pinctrl-fix.service` poke LPASS CSR through busybox `devmem` (`0x0c051000` / `0x0c051004`) while ADSP is still coming up. Result: asynchronous SError ~30 s into boot.

**Fix:**

- Install `kiosk/speaker-route.sh` (**amixer-only**, no `/dev/mem`).
- Mask `pmos-audio-route.service` and `i2c1-pinctrl-fix.service` on the kernel cmdline **and** with `/dev/null` unit symlinks.
- Masked boot image: `work/thinksmart-flash-boot-612-mask.img`. EDL write of **boot only** (not the 6.8 GB system) is `edl ws` to physical partition 0 **sector 925696**.
- Keep `qup-i2c-pinctrl-fix.service` (sysfs unbind/rebind of `78b5000.i2c`); that one is not the MMIO poke.

Recovery when the rootfs is already good: EDL-write only the ~249 MB masked boot image, then reset. Do not reflash the whole system for this panic.

### 4. TAS5782M missing on 6.12

6.12 has **no in-tree TAS5782M**. The 6.19 out-of-tree `.ko` has the wrong vermagic.

**Fix:** rebuild `snd-soc-tas5782m-dbg.ko` from rickx `sources/driver` against **msm8953-mainline linux v6.12.0-r2** with GCC (`CONFIG_CC_IS_GCC=y`). Install under `/lib/modules/$(uname -r)/extra`, `depmod`, `modprobe snd_soc_tas5782m_dbg`. Firmware `tas5728m_dsp_lenovo_cd-18781y.bin` is cached from I2C `0x49`. Card name `cd-18781y`.

On-device kbuild uses ~1.9 GiB RAM and can fill the 6.4 G root. Build on a bigger machine when you can.

### 5. Speaker route inverted (PRI vs QUAT)

Stock `pmos-audio-route` turns **PRI_MI2S_RX** on and **QUAT_MI2S_RX** off. TAS playback is **Quaternary MI2S**. Do not OR TER bit `0x00200000` into the speaker iomux (it steals QUAT BCLK).

**Fix:** `QUAT_MI2S_RX Audio Mixer MultiMedia1=1`, `PRI_MI2S_RX Audio Mixer MultiMedia1=0`, Headphone Jack pin-switch on. Amp `Speaker Amp Master Playback Volume` via `amixer -c 0 cset name=...` (not `sset`). Comfortable analog: **50/85** (range 0–85). 85 is painfully loud.

TAS needs ~500–700 ms after Hi-Z to reload DSP firmware. Short UI clicks are silent unless the chip is already in PLAY.

### 6. PipeWire format (s24-32le vs s16le)

If WirePlumber matches the wrong node name, the sink stays **s24-32le** and sounds nearly dead. Volume keys then get cranked to 200–300% and **clip** once the format is corrected.

**Fix:** overlay `kiosk/99-cd18781y-alsa.lua` → `/etc/wireplumber/main.lua.d/99-cd18781y-alsa.lua` so the node is `HiFi__Speaker__sink` at **S16LE 48 kHz 2ch**. `api.alsa.headroom` 8192. Volume daemon cap **1.00** (s16 TAS clips above digital 1.0). Keys: `thinksmart-volume.py`, amp stays 50.

### 7. DSI / KWin DPMS

Black glass with SSH still up is usually KWin DPMS: `card0-DSI-1` `dpms=Off`. Writing backlight **0** can drop DSI so it never comes back without compositor help.

**Fix:** kiosk uses **cage**, not KWin. If you still have Plasma: `kscreen-doctor --dpms on` as `ubuntu` with the Wayland env. Idle blanker must not write brightness 0. Mask `idle-blanker.service` in both the user wants and `/etc/systemd/user/graphical-session.target.wants`. PowerDevil “turn off” `0` means immediate; use `-- -1` for never.

### 8. Capture path

- Pulse/ffmpeg **16 kHz s16** from the HiFi mic **hashes** the DMICs; Grok STT returns empty.
- **Working capture:** `pw-record --rate=48000 --channels=2 --format=s32` from `alsa_input.platform-c051000.sound-card.HiFi__Microphone__source`, then downsample to 16 kHz mono.
- `arecord -D default` failed until `libasound2-plugins` (do not mix neon PipeWire 1.2.x packages with noble `pipewire-alsa` 1.0.5).
- Hardware mic slider must not be left (muted) during mic tests.
- TX Digital 115 clips; ~95 is usable.

### 9. Timezone

The Plasma image ships **Europe/Rome**. Set yours:

```bash
sudo timedatectl set-timezone "$TZ"
```

RTC has no battery (wakes at 1970); `systemd-timesyncd` restores time. Do not set RTC-in-local-TZ.

### 10. 2 GB RAM / 6.4 G root

- Chromium snap, Electron, full Vue/Vite on-device, and `svg.innerHTML` at 24 fps all lose.
- `pkill cage` or `sddm-helper` starts **drkonqi/apport** coredumps that fill the root. Restart the face with `pkill -f '^python3 /usr/local/share/thinksmart-kiosk/thinksmart-face.py'` only. If `:1680` is dead, `pkill -TERM WebKitWebProcess` so SDDM respawns cage.
- Mask `apport` if the unit is missing and systemd still tries to start it.

### 11. Wi-Fi GTK rekey (upstream)

ath10k SDIO GTK rekey dropouts are documented in rickx (`ath10k_core` patch). Inject Wi-Fi at bootstrap time from a **0600** `secrets/wifi.env`; never put the PSK in chat or git.

---

## Installation

Flashing **wipes** Kingston Android 8.1 and whatever was on the eMMC. Bootloader stays locked. Rollback is an EDL restore of **your** dump, not a toggle.

### 0. Prepare the flash host

```bash
cd /path/to/thinksmart-flash
./tools/edl.sh --help
```

First run clones [bkerler/edl](https://github.com/bkerler/edl) into `tools/edl`, creates `tools/edl-venv`, installs `tools/edl/requirements.txt`, and copies the Firehose loader from `tools/loaders/`. Both `tools/edl` and `tools/edl-venv` are gitignored.

This GitHub tree omits:

- `dump/` — your EDL Android rollback (required before the first flash)
- `images/*.img` — rickx bootstrap and Plasma 6 Ubuntu (GitHub 100 MB limit)
- `work/thinksmart-flash-boot-612*.img` — hybrid boot partitions (~249 MB)
- `tools/edl` / `tools/edl-venv` — created by `tools/edl.sh`
- `secrets/wifi.env` — copy from `secrets/wifi.env.example`
- `voice-assistant` and the Bloub streamer — companion PC, see [`companion/README.md`](companion/README.md)

Put images in `images/`:

- `thinksmart-flash-bootstrap.img` (+ `.sha256`) — rickx generic bootstrap, renamed
- `thinksmart-flash-bootstrap-boot.img` — `pmOS_boot` extract used by `repair-ubuntu-boot.sh`
- `thinksmart-flash.img` (~6.8 GiB) — rickx Plasma 6 Ubuntu, renamed
- `prebuilt/lk2nd.img` from rickx (or copy into this tree)

Wi-Fi: `secrets/wifi.env` mode 600:

```
SSID=YourNetwork
PSK=your-passphrase
```

`secrets/` is mode 700. MEGA HTTP 509 (quota) is common when fetching the Ubuntu image; resume the `.megatmp.*` file.

### 1. Enter EDL and dump (required once)

Power **off**. Unplug USB. Hold **Vol+ and Vol−**, plug the **bottom USB-C** into a USB 2 port, keep holding ~3 s. Screen stays dark.

```bash
python3 wait-edl.py          # waits for 05c6:9008
./tools/edl.sh printgpt | tee dump/printgpt.txt
./tools/edl.sh rl dump --genxml
```

Expect CPU APQ8053, `total_blocks:15269888`. Keep `dump/` off git. Without this dump there is no way back to Teams/Android.

If `edl` hangs at “Device detected” then `USBError(13)`: unplug, re-enter EDL, do not leave it wedged on the bus.

### 2. First Ubuntu (GPT rewrite)

Only if the eMMC still has the **stock** Android GPT (`system` ~1.5 GiB). After rewrite, `system` starts at sector **923648**, **14280671** sectors (~6.8 GiB).

1. Personalize bootstrap Wi-Fi with rickx `prepare-pmos-ssh-bootstrap-image.sh` (SSID/PSK from `secrets/wifi.env`). Output: `images/thinksmart-flash-bootstrap-wifi.img`.
2. `edl w boot prebuilt/lk2nd.img` → sector **790528**.
3. `edl w system images/thinksmart-flash-bootstrap-wifi.img` then `edl reset` → sector **923648**.
4. Bootstrap USB net is `172.16.42.1` (device). SSH `pmos` / `thinksmart`. Run `sudo /usr/local/sbin/apply-ubuntu-gpt.sh`. Shut down.
5. Re-enter EDL. Do **not** flash the raw MEGA Ubuntu image until boot files are repaired (next step).

If GPT and lk2nd are already in place, only `edl w system <image>` is required, and it **wipes** the current root.

### 3. Build the hybrid 6.12 system image

1. Run `repair-ubuntu-boot.sh` if p1 is empty.
2. Replace p1 with 6.12 vmlinuz/initramfs/Himax DTB and extlinux `work/thinksmart-flash-extlinux.conf` (append `lk2nd.pass-simplefb` plus the image UUIDs). Add cmdline  
   `systemd.mask=pmos-audio-route.service systemd.mask=i2c1-pinctrl-fix.service`.
3. Inject `work/pmos-mods/modules/6.12.0-postmarketos-qcom-msm8953/` into p2.
4. EDL:

```bash
./tools/edl.sh --memory=eMMC w system images/thinksmart-flash.img
./tools/edl.sh reset
```

Write is ~3–4 minutes on USB2 (~30 MB/s). Confirm `Wrote ... to sector 923648`. A following `USBError(5)` on reset is normal if `Wrote` succeeded. Leave the cable in the USB 2 hub until then.

First boot: lk2nd splash, then Linux console, then (stock image) SDDM/Plasma. Wait 1–2 minutes. Login `ubuntu` / `thinksmart`.

Join Wi-Fi on glass or USB gadget `172.16.42.1` if the image has no injected NM profile.

```bash
sudo timedatectl set-timezone "$TZ"
```

### 4. Audio on the panel

`tools/deploy-kiosk.sh` (next step) installs `kiosk/99-cd18781y-alsa.lua` and `kiosk/speaker-route.sh`. After SSH, confirm the kernel and codec, then test playback:

1. Confirm `uname -r` is `6.12.0-postmarketos-qcom-msm8953` and `lsmod` includes `snd_soc_tas5782m_dbg`.
2. Overlay `/etc/wireplumber/main.lua.d/99-cd18781y-alsa.lua` — S16LE 48 kHz `HiFi__Speaker__sink`.
3. `/usr/local/bin/speaker-route.sh` — QUAT on, PRI off, amp 50, no `devmem`.
4. `ubuntu` in groups `audio` and `input`.
5. Test as `ubuntu` (not root) with the session Pulse env:

```bash
export XDG_RUNTIME_DIR=/run/user/1000
export PULSE_SERVER=unix:/run/user/1000/pulse/native
wpctl status
pw-play --latency=120ms /usr/share/sounds/freedesktop/stereo/audio-volume-change.oga
```

Mic slider not-left. Capture test:

```bash
pw-record --rate=48000 --channels=2 --format=s32 --target \
  alsa_input.platform-c051000.sound-card.HiFi__Microphone__source /tmp/mic.wav
```

### 5. Cage kiosk (drop Plasma for RAM)

Edit `kiosk/kiosk.env` as in [Configure before you copy files](#configure-before-you-copy-files), then from the flash host:

```bash
./tools/deploy-kiosk.sh ubuntu@PANEL_IPV4
```

That tars `kiosk/` over SSH and runs `kiosk/install-panel.sh` as root on the panel: cage + GTK4/WebKit packages, files under `/usr/local/share/thinksmart-kiosk/`, WirePlumber overlay, `speaker-route.sh`, volume and wake units, SDDM session `thinksmart-kiosk.desktop`, groups `audio`/`input`, and masks `pmos-audio-route.service` / `i2c1-pinctrl-fix.service`.

Live compositor path is SDDM → cage (`Exec=/usr/bin/cage -s …/thinksmart-face.py`). `kiosk/thinksmart-kiosk.service` is a template only; a `pkill` of cage kills the session. Restart the face with:

```bash
pkill -f '^python3 /usr/local/share/thinksmart-kiosk/thinksmart-face.py'
curl http://127.0.0.1:1680/state
```

An old `/usr/local/share/xiaozhi-kiosk` path can stay as a symlink to the new directory. Wake word: `thinksmart-wake.py` RMS-gates `pw-record`. If Sherpa KWS is installed it POSTs `/wake` on a spotter hit; otherwise it POSTs `/api/transcribe` on the companion, regex for hey/ok grok, then `POST http://127.0.0.1:1680/wake`. The wake unit runs `/usr/bin/python3`. Do not install a native 小智 client. This kiosk talks HTTP to `VOICE_HOST:8765`. Face and wake exit if `VOICE_HOST` is missing or still the `192.0.2.10` example.

Cache-bust: bump `thinksmart-kiosk.html?v=N` in `thinksmart-face.py` and `thinksmart-kiosk.js?v=` in the HTML.

The kiosk polls `SW_MICROPHONE_INSERT` on `/dev/input/event0`. Slider left → face `sleep`, status `muted`, hint “mic muted”; hold-to-talk and wake stay off.

### 6. Companion voice-assistant

This program is **not in this repository**. On `VOICE_HOST`, run your `voice-assistant` tree so it matches [`companion/README.md`](companion/README.md):

```bash
cd /path/to/voice-assistant
# .env mode 0600: XAI_API_KEY, VOICE_KITCHEN_BACKEND=voice
# optional HA: secrets/ha.env (USER, PASSWORD)
# optional Tavily: secrets/tavily.env
.venv/bin/python -m voice_assistant start
curl -sk https://127.0.0.1:8765/api/health
```

Health should show `kitchen_backend=voice`, `voice=grok-voice-latest`, `voice_name=eve`. `ha_mcp=true` if HA creds are present.

Grok Voice tools (in `voice_assistant/grok_voice.py`):

- `web_search` (set the search location to your region)
- Tavily remote MCP (`https://mcp.tavily.com/mcp`) if a key is present
- Client functions `ha_turn_on` / `ha_turn_off` / `ha_status` → local `ha_mcp.py` → `http://HA_HOST:8123/api/mcp`

**Do not** put the HA MCP URL in Voice `type: mcp`. xAI’s cloud cannot reach RFC1918. The companion runs the function and returns `function_call_output` on the Voice websocket.

```bash
sudo ufw allow from LAN_CIDR to any port 8765 proto tcp
```

TLS: the panel uses `curl -sk` to the companion cert (no verification). Keep `:8765`/`:8766` UFW'd to `LAN_CIDR`. `kiosk.env` must never hold `XAI_API_KEY`. Browsers that open the companion UI need to trust `/cert.pem`.

### 7. Bloub streamer

This program is **not in this repository**. On `FACE_HOST`, run a Node + `sharp` streamer that matches [`companion/README.md`](companion/README.md). Bind **only the LAN NIC** (`BLOUB_BIND` / `BLOUB_PORT`, default `:8766`):

- HTTP `GET /face.jpg` (single baseline JPEG), `GET /face.mjpeg`, `GET|POST /face?name=`, `GET /health`
- 12 fps JPEG ~720 px, cream `#eceae6` on paper `#1a1a1a`
- systemd user unit with linger enabled is a good pattern
- UFW: `8766/tcp` from `LAN_CIDR` only

The panel **must not** open `:8766` from WebKit (sandbox + firewall). `thinksmart-face.py` proxies `GET /bot.jpg` (one complete JPEG per request). WebKitGTK 6 does not paint `multipart/x-mixed-replace` in `<img>`, so the glass polls `/bot.jpg` instead of hanging on `/bot.mjpeg`.

Face map: idle→idle, listen→wide, thinking→thinking, speak→notify, error→alert, sleep→sleep.

### 8. Home Assistant (optional)

1. Confirm MCP: `http://HA_HOST:8123/api/mcp` with a local user.
2. Companion `ha_mcp.py` logs in, lists tools, calls `intent__HassTurnOn` / `HassTurnOff` / `homeassistant__GetLiveContext`.
3. Restart Voice after HA creds exist so `_tools()` includes the three functions.
4. Spoken tests: “what lights are on”, “turn on the kitchen lights” (whatever entities you have).

A public MCP gateway in front of HA is unnecessary for this kiosk and a bad idea unless you already have a machine token and want tools beyond the house.

---

## Bloub library

[jeremy-prt/bloub](https://github.com/jeremy-prt/bloub) is a MIT-licensed Vue 3 + Vite recreation of the xAI Grok bot mark. MIT covers **the code**, not xAI’s design. Not affiliated with xAI or SpaceX.

### Engine

| | |
| --- | --- |
| Path | `src/bot` — framework-free `BotEngine.sample(t)` |
| Shape | One filled path, 14 states, eyes as **mask holes** |
| Rest pose | Eyes lean ~26°, body a circle (&lt;0.7% radial deviation) |
| Life | Gaze drift + blinks; exponential ease-outs, no body overshoot |
| Customiser | Body only on `idle` / `wink` / `wide` / `notify` / `swirl` |
| Vue app | `BloubBot.vue`, pnpm, Tailwind 4 — **too heavy for the panel** |

Colors on this kiosk: body `#eceae6`, paper `#1a1a1a`.

### Why it is not running on the ThinkSmart

WebKitGTK 6 on 2 GB RAM:

- `svg.innerHTML` every frame at 24 fps → ~99% CPU, frozen face.
- `BotEngine.sample()` at 10 fps on device → ~83% CPU, looks stuck.
- CSS keyframe loops re-raster the mask and also spin.

### What was tried, in order

1. **On-device Vue/IIFE** (removed from this tree). Factory helper cannot be named `el` if `mount(el)` exists — inner `el('svg')` TypeErrors. Use `node(tag, attrs)`.
2. **Baked poses** (`kiosk-poses.json`): static cream circle + precomputed eyes; idle blink by hiding holes ~140 ms every 3–6 s. Better, still extra JS on the panel.
3. **Live path:** render bloub on the companion (Node + `sharp`) and serve **baseline JPEGs**. Panel polls `<img>` via `/bot.jpg`. JPEG stills in `kiosk/faces/` are the fallback if the companion is down.

License file copied next to the kiosk bundle: `kiosk/bloub-LICENSE.txt`.

Do not put generated reply text over the face (long answers cover the bot). Clock and a one-line hint only.

---

## Daily use

- **Hold** the screen, talk, release (minimum ~900 ms). Hint: “release to send”.
- Or say **hey grok** / **ok grok**. Hint: “talk, then pause”.
- Eve answers; hint becomes **I’m listening** for 15 seconds. Keep talking for a follow-up. Ten follow-ups max, then idle. Empty/TV clips are not spoken back.
- Volume keys step PipeWire 0.15–1.00. Amp stays at 50/85.
- Mic slider left: sleep pose, no listen.

Logs:

| Where | Path |
| --- | --- |
| Panel face | stdout of `thinksmart-face.py`; `/tmp/kiosk-wake.log` |
| Volume | `/tmp/thinksmart-volume.log` |
| Companion Voice | `voice-assistant/logs/server.out`, `logs/YYYY-MM-DD.jsonl` |
| Last companion clip | `/tmp/last-turn.wav` on `VOICE_HOST` |
| Last panel TTS | `/tmp/kiosk-tts.wav` (24 kHz Eve) and `/tmp/kiosk-tts-hot.wav` (48 kHz stereo) |

---

## Operations

### Restart the face

```bash
pkill -f '^python3 /usr/local/share/thinksmart-kiosk/thinksmart-face.py'
# if :1680 stays down:
pkill -TERM WebKitWebProcess
```

Never `pkill cage` or `sddm-helper`.

### Restart Voice

```bash
cd /path/to/voice-assistant
.venv/bin/python -m voice_assistant stop
.venv/bin/python -m voice_assistant start
```

### Pulse environment (panel)

```bash
export XDG_RUNTIME_DIR=/run/user/1000
export PULSE_SERVER=unix:/run/user/1000/pulse/native
```

Root has no session PipeWire; tests as root are silent or 44-byte WAVs.

### Secrets

| File | Mode | Contains |
| --- | --- | --- |
| Companion `voice-assistant/.env` | 0600 | `XAI_API_KEY`, `VOICE_KITCHEN_BACKEND=voice` |
| Companion `secrets/ha.env` | 0600 | HA username/password (optional) |
| Companion `secrets/tavily.env` | 0600 | Tavily (optional) |
| `thinksmart-flash/secrets/wifi.env` | 0600 | SSID/PSK |

Do not put keys in chat, git, or this README.

### EDL boot-only patch (SError recovery)

```bash
./tools/edl.sh ws 925696 work/thinksmart-flash-boot-612-mask.img
```

### SSH to the panel

Default image login is `ubuntu` / `thinksmart` until you change it. Banner timeouts happen under WebKit load; ping/TCP 22 can succeed while SSH fails. Wait or TERM WebKit, then retry. mDNS (`*.local`) is unreliable on this image; use the DHCP IPv4.

---

## Other images

These were evaluated and **not** used for this kiosk:

- **[justhalfbit/thinksmart-ubuntu-image](https://github.com/justhalfbit/thinksmart-ubuntu-image)** — Weston + on-device 小智, Chinese wake 「小麦小麦」, kernel 6.19.5. Attractive, wrong kernel for Himax glass, would wipe this stack.
- **xiaozhi-hub-server + xiaozhi_linux_rs** — Opus/VAD/frame-duration mismatches, no local English wake, extra RAM. Binary and unit may still be on disk; keep them **disabled**.
- **n8n → Grok Bot webhook** — STT → webhook → long wait → TTS. Too slow for the panel. `VOICE_KITCHEN_BACKEND=voice` skips it.
- On-device LLM, official Grok Android app (needs Android 9+ / arm64 / Play), Grok Bot Electron on 2 GB.

---

## Credits

- Device bring-up: [rickx/ubuntu-thinksmart](https://github.com/rickx/ubuntu-thinksmart) (Ubuntu 24.04, lk2nd, bootstrap, TAS work, FelixKa pmOS device package).
- Kernel: postmarketOS `linux-postmarketos-qcom-msm8953`.
- EDL: [bkerler/edl](https://github.com/bkerler/edl).
- Kiosk inspiration: [justhalfbit](https://github.com/justhalfbit) (xiaozhi client/hub and later Ubuntu image). This tree does not run that image.
- Face engine: [jeremy-prt/bloub](https://github.com/jeremy-prt/bloub) (MIT).
- Voice: xAI Grok Voice Agent API (`wss://api.x.ai/v1/realtime`).
- Optional Home Assistant MCP on the LAN.

Not affiliated with Canonical, Lenovo, Qualcomm, or xAI.
