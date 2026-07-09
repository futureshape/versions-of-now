# Speaking Clock

This install turns a Raspberry Pi into a telephone-style speaking clock. It
plays through the system audio output, so a vintage telephone handset headset or
USB audio adapter can be plugged in directly.

The runtime also works on macOS for testing, using the built-in `say` and
`afplay` commands.

## Authenticity Model

The clock follows the recognisable UK speaking-clock pattern:

- Announcements are scheduled every 10 seconds by default.
- The wording is `At the third stroke, the time will be ...`.
- Exact minutes use `precisely`.
- Zero minutes use `o'clock`, including times such as `twelve o'clock and ten
  seconds`.
- Three 1 kHz strokes are generated, one second apart, with the third stroke
  scheduled on the announced time.
- On Raspberry Pi, the service waits for the system clock to report NTP sync
  before announcing.

This does not include copyrighted historical BT recordings. The Raspberry Pi
default is the local neural Piper voice `en_GB-alba-medium`; `espeak-ng` remains
installed as a simple fallback. macOS tests use `Daniel` through `say` when
available. The physical telephone headset does much of the useful band-limiting.

## Hardware Assumptions

- Raspberry Pi running Raspberry Pi OS Lite or another systemd-based Debian
  Linux.
- Network access during installation for APT packages and NTP time sync.
- A working system audio output, such as the Pi audio jack, HDMI audio, or a USB
  audio adapter wired into the vintage handset.
- The local timezone is configured on the Pi before the clock is installed.

No Home Assistant, MQTT, cloud service, or display stack is required.

## macOS Test Run

From the repository root:

```sh
cd rpi/speaking-clock
python3 speaking_clock.py --test-time 12:34:50
```

That speaks one fixed phrase immediately, then plays the three strokes. To test
real scheduling against the Mac system clock:

```sh
python3 speaking_clock.py --once
```

To check phrasing without audio:

```sh
python3 speaking_clock.py --dry-run --test-time 09:08:30
```

If the `Daniel` voice is not installed on a Mac, the runtime falls back to the
system voice. You can pick another local voice with:

```sh
python3 speaking_clock.py --test-time 12:00:00 --voice "Samantha"
```

## Raspberry Pi Install

1. Flash Raspberry Pi OS Lite and configure Wi-Fi or Ethernet, SSH, locale,
   timezone, and the admin user with Raspberry Pi Imager.
2. Boot the Pi and copy this folder to it:

   ```sh
   scp -r rpi/speaking-clock <user>@<pi-hostname>.local:/tmp/
   ```

3. Run the installer:

   ```sh
   ssh <user>@<pi-hostname>.local
   cd /tmp/speaking-clock
   sudo ./install.sh
   ```

4. Check the service:

   ```sh
   sudo systemctl status speaking-clock.service --no-pager
   sudo journalctl -u speaking-clock.service -f
   ```

The installer creates a locked `speakingclock` user, installs `python3`,
`python3-venv`, `espeak-ng`, and `alsa-utils`, creates a Piper virtualenv at
`/opt/speaking-clock/venv`, downloads the `en_GB-alba-medium` voice to
`/opt/speaking-clock/voices`, enables system time synchronization where
available, copies the runtime to `/opt/speaking-clock/`, and creates two systemd
services: `speaking-clock-piper.service` keeps the Piper model loaded through a
local HTTP server, and `speaking-clock.service` schedules the announcements.

## Configuration

Runtime arguments live in:

```sh
/etc/default/speaking-clock
```

The default is:

```sh
SPEAKING_CLOCK_ARGS="--interval 10 --backend piper --player aplay --voice en_GB-alba-medium --piper-url http://127.0.0.1:5000/ --piper-data-dir /opt/speaking-clock/voices --volume 100 --require-sync"
```

Useful changes:

- Use a specific USB audio adapter:

  ```sh
  SPEAKING_CLOCK_ARGS="--interval 10 --backend piper --player aplay --audio-device plughw:1,0 --voice en_GB-alba-medium --piper-url http://127.0.0.1:5000/ --piper-data-dir /opt/speaking-clock/voices --volume 100 --require-sync"
  ```

- Try the old espeak-ng fallback:

  ```sh
  --backend espeak-ng --voice en-gb --rate 140 --volume 160
  ```

- Add installation wording:

  ```sh
  --source-label "from Versions of Now"
  ```

- Compensate if the third stroke is consistently late by 50 ms:

  ```sh
  --playback-latency 0.05
  ```

Restart after changes:

```sh
sudo systemctl restart speaking-clock.service
```

## Audio Troubleshooting

List ALSA devices:

```sh
aplay -l
```

Play a generated test announcement without installing the service:

```sh
python3 /opt/speaking-clock/speaking_clock.py --test-time 12:34:50 --backend piper --player aplay --voice en_GB-alba-medium --piper-url http://127.0.0.1:5000/ --piper-data-dir /opt/speaking-clock/voices
```

If the service logs `audio open error`, set `--audio-device` in
`/etc/default/speaking-clock`. For a USB adapter this is often `plughw:1,0`, but
check `aplay -l` on the actual Pi.

If the service keeps saying it is waiting for sync, check:

```sh
timedatectl status
```

## References

Reference notes checked on 2026-06-23:

- `https://en.wikipedia.org/wiki/Speaking_clock`
- `https://github.com/OHF-Voice/piper1-gpl`
- `https://huggingface.co/rhasspy/piper-voices/tree/main/en/en_GB`
