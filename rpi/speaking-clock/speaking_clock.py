#!/usr/bin/env python3
"""Telephone-style speaking clock for Raspberry Pi OS and macOS."""

from __future__ import annotations

import argparse
import contextlib
import dataclasses
import datetime as dt
import json
import logging
import math
import os
import platform
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import wave
from pathlib import Path


LOG = logging.getLogger("speaking-clock")

SMALL_NUMBERS = {
    0: "zero",
    1: "one",
    2: "two",
    3: "three",
    4: "four",
    5: "five",
    6: "six",
    7: "seven",
    8: "eight",
    9: "nine",
    10: "ten",
    11: "eleven",
    12: "twelve",
    13: "thirteen",
    14: "fourteen",
    15: "fifteen",
    16: "sixteen",
    17: "seventeen",
    18: "eighteen",
    19: "nineteen",
}

TENS = {
    20: "twenty",
    30: "thirty",
    40: "forty",
    50: "fifty",
}


class ClockError(RuntimeError):
    """Expected runtime failure with a user-readable message."""


@dataclasses.dataclass(frozen=True)
class RenderedClip:
    path: Path | None
    duration: float
    text: str = ""
    engine: "SpeechEngine | None" = None


@dataclasses.dataclass(frozen=True)
class SpeechEngine:
    backend: str
    voice: str | None
    rate: int
    volume: int
    default_voice: bool
    piper_python: str = ""
    piper_data_dir: str = ""
    piper_length_scale: float = 1.0
    piper_noise_scale: float = 0.667
    piper_noise_w_scale: float = 0.8
    piper_sentence_silence: float = 0.0
    piper_url: str = ""
    piper_timeout: float = 20.0


@dataclasses.dataclass(frozen=True)
class AudioPlayer:
    player: str
    audio_device: str | None

    def play(self, path: Path) -> None:
        if self.player == "aplay":
            command = ["aplay", "-q"]
            if self.audio_device:
                command.extend(["-D", self.audio_device])
            command.append(str(path))
        elif self.player == "afplay":
            command = ["afplay", str(path)]
        else:
            raise ClockError(f"unsupported audio player: {self.player}")

        run_command(command)


def play_speech_clip(clip: RenderedClip, player: AudioPlayer) -> None:
    if clip.path is not None:
        player.play(clip.path)
        return

    if clip.engine and clip.engine.backend == "say":
        command = ["say", "-r", str(clip.engine.rate)]
        if clip.engine.voice:
            command.extend(["-v", clip.engine.voice])
        command.append(clip.text)
        run_command(command)
        return

    raise ClockError("speech clip has no playable audio")


def number_words(value: int) -> str:
    if value < 0 or value > 99:
        raise ValueError("number_words only supports values from 0 to 99")

    if value < 20:
        return SMALL_NUMBERS[value]

    ten = (value // 10) * 10
    unit = value % 10
    if unit == 0:
        return TENS[ten]
    return f"{TENS[ten]} {SMALL_NUMBERS[unit]}"


def hour_words(hour: int, hour_mode: str) -> str:
    if hour_mode == "24":
        return number_words(hour)

    display_hour = hour % 12
    if display_hour == 0:
        display_hour = 12
    return number_words(display_hour)


def minute_words(minute: int) -> str:
    if minute == 0:
        return "o'clock"
    if minute < 10:
        return f"oh {number_words(minute)}"
    return number_words(minute)


def seconds_words(second: int) -> str:
    if second == 0:
        return "precisely"
    second_unit = "second" if second == 1 else "seconds"
    return f"and {number_words(second)} {second_unit}"


def build_announcement(
    target_time: dt.datetime,
    *,
    hour_mode: str = "12",
    source_label: str = "",
) -> str:
    """Build a UK speaking-clock style announcement for a local target time."""
    hour = hour_words(target_time.hour, hour_mode)
    minute = minute_words(target_time.minute)
    seconds = seconds_words(target_time.second)
    source = f" {source_label.strip()}" if source_label.strip() else ""

    return f"At the third stroke, the time{source} will be {hour} {minute} {seconds}."


def parse_test_time(value: str, now: dt.datetime | None = None) -> dt.datetime:
    parts = value.split(":")
    if len(parts) not in (2, 3):
        raise argparse.ArgumentTypeError("use HH:MM or HH:MM:SS")

    try:
        hour = int(parts[0])
        minute = int(parts[1])
        second = int(parts[2]) if len(parts) == 3 else 0
    except ValueError as exc:
        raise argparse.ArgumentTypeError("time parts must be numbers") from exc

    if not 0 <= hour <= 23:
        raise argparse.ArgumentTypeError("hour must be 0..23")
    if not 0 <= minute <= 59:
        raise argparse.ArgumentTypeError("minute must be 0..59")
    if not 0 <= second <= 59:
        raise argparse.ArgumentTypeError("second must be 0..59")

    base = now or dt.datetime.now()
    return base.replace(hour=hour, minute=minute, second=second, microsecond=0)


def next_boundary(after_epoch: float, interval_seconds: int) -> float:
    return math.ceil(after_epoch / interval_seconds) * interval_seconds


def run_command(command: list[str]) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            command,
            check=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except FileNotFoundError as exc:
        raise ClockError(f"missing command: {command[0]}") from exc
    except subprocess.CalledProcessError as exc:
        message = exc.stderr.strip() or exc.stdout.strip() or str(exc)
        raise ClockError(f"{command[0]} failed: {message}") from exc


def command_output(command: list[str]) -> str | None:
    try:
        result = subprocess.run(
            command,
            check=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
    except (FileNotFoundError, subprocess.CalledProcessError):
        return None
    return result.stdout.strip()


def piper_python_command(args: argparse.Namespace) -> str:
    if args.piper_python:
        return args.piper_python

    install_python = "/opt/speaking-clock/venv/bin/python"
    if Path(install_python).exists():
        return install_python

    return sys.executable


def piper_available(args: argparse.Namespace) -> bool:
    python = piper_python_command(args)
    if not Path(python).exists() and shutil.which(python) is None:
        return False

    return command_output([
        python,
        "-c",
        "import importlib.util; print('ok' if importlib.util.find_spec('piper') else 'missing')",
    ]) == "ok"


def select_speech_engine(args: argparse.Namespace) -> SpeechEngine:
    backend = args.backend
    system = platform.system()

    if backend == "auto":
        if system == "Darwin" and shutil.which("say"):
            backend = "say"
        elif piper_available(args):
            backend = "piper"
        elif shutil.which("espeak-ng"):
            backend = "espeak-ng"
        elif shutil.which("say"):
            backend = "say"
        else:
            raise ClockError("could not find piper, espeak-ng, or macOS say")

    if backend == "say" and not shutil.which("say"):
        raise ClockError("macOS say is not available")
    if backend == "espeak-ng" and not shutil.which("espeak-ng"):
        raise ClockError("espeak-ng is not installed")
    if backend == "piper" and not args.piper_url and not piper_available(args):
        raise ClockError("Piper is not installed or cannot be imported")

    default_voice = False
    voice = args.voice
    if voice is None:
        if backend == "say":
            voice = "Daniel"
            default_voice = True
        elif backend == "espeak-ng":
            voice = "en-gb"
            default_voice = True
        elif backend == "piper":
            voice = "en_GB-alba-medium"
            default_voice = True

    if args.rate:
        rate = args.rate
    elif backend == "say":
        rate = 145
    else:
        rate = 140

    return SpeechEngine(
        backend=backend,
        voice=voice,
        rate=rate,
        volume=args.volume,
        default_voice=default_voice,
        piper_python=piper_python_command(args),
        piper_data_dir=args.piper_data_dir,
        piper_length_scale=args.piper_length_scale,
        piper_noise_scale=args.piper_noise_scale,
        piper_noise_w_scale=args.piper_noise_w_scale,
        piper_sentence_silence=args.piper_sentence_silence,
        piper_url=args.piper_url,
        piper_timeout=args.piper_timeout,
    )


def select_audio_player(args: argparse.Namespace) -> AudioPlayer:
    player = args.player
    system = platform.system()

    if player == "auto":
        if system == "Darwin" and shutil.which("afplay"):
            player = "afplay"
        elif shutil.which("aplay"):
            player = "aplay"
        elif shutil.which("afplay"):
            player = "afplay"
        else:
            raise ClockError("could not find aplay or afplay")

    if player == "aplay" and not shutil.which("aplay"):
        raise ClockError("aplay is not installed")
    if player == "afplay" and not shutil.which("afplay"):
        raise ClockError("afplay is not available")

    return AudioPlayer(player=player, audio_device=args.audio_device)


def piper_readiness_url(synthesize_url: str) -> str:
    parsed = urllib.parse.urlparse(synthesize_url)
    return urllib.parse.urlunparse(parsed._replace(path="/voices", query="", fragment=""))


def wait_for_piper_http(synthesize_url: str, timeout: float) -> None:
    readiness_url = piper_readiness_url(synthesize_url)
    started_at = time.monotonic()

    while True:
        try:
            with urllib.request.urlopen(readiness_url, timeout=2.0) as response:
                if 200 <= response.status < 300:
                    LOG.info("Piper HTTP server is ready")
                    return
        except (urllib.error.URLError, TimeoutError):
            pass

        if timeout > 0 and time.monotonic() - started_at >= timeout:
            raise ClockError("Piper HTTP server did not become ready before timeout")

        time.sleep(1.0)


def render_piper_http(text: str, engine: SpeechEngine, voice: str, path: Path) -> None:
    payload = {
        "text": text,
        "voice": voice,
        "length_scale": engine.piper_length_scale,
        "noise_scale": engine.piper_noise_scale,
        "noise_w_scale": engine.piper_noise_w_scale,
    }
    request = urllib.request.Request(
        engine.piper_url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=engine.piper_timeout) as response:
            if not 200 <= response.status < 300:
                raise ClockError(f"Piper HTTP returned status {response.status}")
            path.write_bytes(response.read())
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace").strip()
        message = f"Piper HTTP returned status {exc.code}"
        if detail:
            message = f"{message}: {detail}"
        raise ClockError(message) from exc
    except (urllib.error.URLError, TimeoutError) as exc:
        raise ClockError(f"Piper HTTP request failed: {exc}") from exc


def render_speech(text: str, engine: SpeechEngine, directory: Path) -> RenderedClip:
    voices = [engine.voice]
    if engine.default_voice and engine.voice:
        voices.append(None)

    last_error: ClockError | None = None
    for voice in voices:
        path = directory / ("speech.aiff" if engine.backend == "say" else "speech.wav")
        with contextlib.suppress(FileNotFoundError):
            path.unlink()

        try:
            if engine.backend == "say":
                command = ["say", "-r", str(engine.rate), "-o", str(path)]
                if voice:
                    command.extend(["-v", voice])
                command.append(text)
            elif engine.backend == "espeak-ng":
                command = [
                    "espeak-ng",
                    "-s",
                    str(engine.rate),
                    "-a",
                    str(engine.volume),
                    "-w",
                    str(path),
                ]
                if voice:
                    command.extend(["-v", voice])
                command.append(text)
            elif engine.backend == "piper":
                if not voice:
                    raise ClockError("Piper requires a voice/model name")

                if engine.piper_url:
                    render_piper_http(text, engine, voice, path)
                    command = []
                else:
                    command = [
                        engine.piper_python,
                        "-m",
                        "piper",
                        "-m",
                        voice,
                        "-f",
                        str(path),
                        "--length-scale",
                        str(engine.piper_length_scale),
                        "--noise-scale",
                        str(engine.piper_noise_scale),
                        "--noise-w-scale",
                        str(engine.piper_noise_w_scale),
                        "--sentence-silence",
                        str(engine.piper_sentence_silence),
                        "--volume",
                        str(engine.volume / 100.0),
                    ]
                    if engine.piper_data_dir:
                        command.extend(["--data-dir", engine.piper_data_dir])
                    command.extend(["--", text])
            else:
                raise ClockError(f"unsupported speech backend: {engine.backend}")

            if command:
                run_command(command)
            duration = audio_duration(path, fallback_text=text, fallback_rate=engine.rate)
            if duration > 0.05:
                return RenderedClip(path=path, duration=duration)

            if engine.backend == "say":
                LOG.warning("say produced an empty output file; using live say playback")
                return RenderedClip(
                    path=None,
                    duration=estimate_spoken_duration(text, engine.rate),
                    text=text,
                    engine=dataclasses.replace(engine, voice=voice),
                )

            raise ClockError(f"{engine.backend} produced an empty speech file")
        except ClockError as exc:
            last_error = exc
            if voice and engine.default_voice:
                LOG.warning("default voice %s failed; retrying with system voice", voice)
                continue
            raise

    raise last_error or ClockError("speech rendering failed")


def audio_duration(path: Path, *, fallback_text: str, fallback_rate: int) -> float:
    if path.suffix.lower() == ".wav":
        with wave.open(str(path), "rb") as clip:
            return clip.getnframes() / float(clip.getframerate())

    duration = aiff_duration(path)
    if duration is not None:
        return duration

    info_duration = afinfo_duration(path)
    if info_duration is not None:
        return info_duration

    return estimate_spoken_duration(fallback_text, fallback_rate)


def aiff_duration(path: Path) -> float | None:
    try:
        import aifc  # type: ignore[deprecated]
    except Exception:
        return None

    try:
        with aifc.open(str(path), "rb") as clip:
            return clip.getnframes() / float(clip.getframerate())
    except Exception:
        return None


def afinfo_duration(path: Path) -> float | None:
    if not shutil.which("afinfo"):
        return None

    output = command_output(["afinfo", str(path)])
    if not output:
        return None

    match = re.search(r"estimated duration:\s*([0-9.]+)\s*sec", output)
    if not match:
        return None
    return float(match.group(1))


def estimate_spoken_duration(text: str, words_per_minute: int) -> float:
    words = re.findall(r"[A-Za-z0-9']+", text)
    rate = max(words_per_minute, 80)
    return max(1.0, (len(words) / rate) * 60.0 + 0.4)


def write_strokes_wav(
    path: Path,
    *,
    frequency: float,
    stroke_duration: float,
    sample_rate: int,
    amplitude: float,
) -> RenderedClip:
    total_duration = 2.0 + stroke_duration + 0.05
    frame_count = int(total_duration * sample_rate)
    fade_duration = min(0.008, stroke_duration / 4.0)
    max_sample = int(32767 * amplitude)

    with wave.open(str(path), "wb") as clip:
        clip.setnchannels(1)
        clip.setsampwidth(2)
        clip.setframerate(sample_rate)

        for frame in range(frame_count):
            t = frame / sample_rate
            value = 0.0

            for offset in (0.0, 1.0, 2.0):
                local = t - offset
                if 0.0 <= local < stroke_duration:
                    envelope = 1.0
                    if fade_duration > 0:
                        envelope = min(
                            1.0,
                            local / fade_duration,
                            (stroke_duration - local) / fade_duration,
                        )
                    value += math.sin(2.0 * math.pi * frequency * local) * envelope

            sample = int(max(-1.0, min(1.0, value)) * max_sample)
            clip.writeframes(struct.pack("<h", sample))

    return RenderedClip(path=path, duration=total_duration)


def clock_sync_state() -> bool | None:
    if shutil.which("timedatectl"):
        output = command_output(["timedatectl", "show", "-p", "NTPSynchronized", "--value"])
        if output == "yes":
            return True
        if output == "no":
            return False

    if shutil.which("chronyc"):
        output = command_output(["chronyc", "tracking"])
        if output:
            if re.search(r"Leap status\s*:\s*Normal", output):
                return True
            if re.search(r"Leap status\s*:\s*Not synchronised", output):
                return False

    return None


def wait_for_clock_sync(timeout: float) -> None:
    started_at = time.monotonic()
    last_report = 0.0

    while True:
        state = clock_sync_state()
        if state is True:
            LOG.info("system clock is synchronized")
            return
        if state is None:
            LOG.warning("could not verify NTP sync on this platform; trusting system clock")
            return

        elapsed = time.monotonic() - started_at
        if timeout > 0 and elapsed >= timeout:
            raise ClockError("system clock did not synchronize before timeout")
        if elapsed - last_report >= 30 or last_report == 0:
            LOG.info("waiting for system clock synchronization")
            last_report = elapsed
        time.sleep(2.0)


def prepare_real_announcement(
    args: argparse.Namespace,
    engine: SpeechEngine,
    directory: Path,
) -> tuple[float, dt.datetime, str, RenderedClip | None]:
    now_epoch = time.time()
    target_epoch = next_boundary(now_epoch + args.min_notice, args.interval)

    for _ in range(8):
        target_time = dt.datetime.fromtimestamp(target_epoch)
        text = build_announcement(
            target_time,
            hour_mode=args.hour_mode,
            source_label=args.source_label,
        )

        if args.dry_run:
            duration = estimate_spoken_duration(text, args.rate or 140)
            clip = None
        else:
            clip = render_speech(text, engine, directory)
            duration = clip.duration

        required_notice = duration + args.gap_before_strokes + 2.0 + args.schedule_margin
        if target_epoch - time.time() >= required_notice:
            return target_epoch, target_time, text, clip

        target_epoch = next_boundary(time.time() + required_notice + 0.2, args.interval)

    raise ClockError("could not schedule an announcement far enough ahead")


def sleep_until_epoch(target_epoch: float) -> None:
    while True:
        remaining = target_epoch - time.time()
        if remaining <= 0:
            return
        if remaining > 1.0:
            time.sleep(min(remaining - 0.5, 1.0))
        elif remaining > 0.05:
            time.sleep(remaining / 2.0)
        else:
            time.sleep(min(remaining, 0.005))


def play_real_announcement(
    args: argparse.Namespace,
    player: AudioPlayer,
    target_epoch: float,
    target_time: dt.datetime,
    text: str,
    speech: RenderedClip,
    strokes: RenderedClip,
) -> None:
    local_time = target_time.astimezone().strftime("%Y-%m-%d %H:%M:%S %Z")
    LOG.info("next announcement targets %s: %s", local_time, text)

    speech_start = target_epoch - 2.0 - args.gap_before_strokes - speech.duration
    sleep_until_epoch(speech_start)
    play_speech_clip(speech, player)

    stroke_start = target_epoch - 2.0 - args.playback_latency
    sleep_until_epoch(stroke_start)
    player.play(strokes.path)


def play_test_announcement(
    args: argparse.Namespace,
    engine: SpeechEngine,
    player: AudioPlayer | None,
) -> None:
    target_time = parse_test_time(args.test_time)
    text = build_announcement(
        target_time,
        hour_mode=args.hour_mode,
        source_label=args.source_label,
    )

    if args.dry_run:
        print(text)
        return

    with tempfile.TemporaryDirectory(prefix="speaking-clock-") as temp_name:
        temp_dir = Path(temp_name)
        speech = render_speech(text, engine, temp_dir)
        strokes = write_strokes_wav(
            temp_dir / "strokes.wav",
            frequency=args.stroke_frequency,
            stroke_duration=args.stroke_duration,
            sample_rate=args.stroke_sample_rate,
            amplitude=args.stroke_amplitude,
        )

        assert player is not None
        LOG.info("test announcement: %s", text)
        play_speech_clip(speech, player)
        time.sleep(args.gap_before_strokes)
        player.play(strokes.path)


def run_clock(args: argparse.Namespace, engine: SpeechEngine, player: AudioPlayer | None) -> None:
    if args.require_sync:
        wait_for_clock_sync(args.sync_timeout)

    if engine.backend == "piper" and engine.piper_url:
        wait_for_piper_http(engine.piper_url, args.piper_startup_timeout)

    once = args.once or args.dry_run

    while True:
        with tempfile.TemporaryDirectory(prefix="speaking-clock-") as temp_name:
            temp_dir = Path(temp_name)
            target_epoch, target_time, text, speech = prepare_real_announcement(args, engine, temp_dir)

            if args.dry_run:
                print(f"{dt.datetime.fromtimestamp(target_epoch).isoformat(timespec='seconds')}  {text}")
                return

            strokes = write_strokes_wav(
                temp_dir / "strokes.wav",
                frequency=args.stroke_frequency,
                stroke_duration=args.stroke_duration,
                sample_rate=args.stroke_sample_rate,
                amplitude=args.stroke_amplitude,
            )

            assert player is not None
            assert speech is not None
            play_real_announcement(args, player, target_epoch, target_time, text, speech, strokes)

        if once:
            return


def positive_float(value: str) -> float:
    parsed = float(value)
    if parsed < 0:
        raise argparse.ArgumentTypeError("must be >= 0")
    return parsed


def interval_value(value: str) -> int:
    parsed = int(value)
    if parsed < 1 or parsed > 60 or 60 % parsed != 0:
        raise argparse.ArgumentTypeError("interval must divide evenly into 60 seconds")
    return parsed


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--once", action="store_true", help="play one real-time announcement and exit")
    parser.add_argument("--dry-run", action="store_true", help="print the next announcement without playing audio")
    parser.add_argument(
        "--test-time",
        metavar="HH:MM[:SS]",
        help="speak one fixed local time immediately; useful on macOS while testing",
    )

    parser.add_argument("--interval", type=interval_value, default=10, help="announcement interval in seconds")
    parser.add_argument("--hour-mode", choices=("12", "24"), default="12", help="spoken hour style")
    parser.add_argument("--source-label", default="", help='optional phrase such as "from Versions of Now"')

    parser.add_argument("--backend", choices=("auto", "espeak-ng", "piper", "say"), default="auto")
    parser.add_argument("--player", choices=("auto", "aplay", "afplay"), default="auto")
    parser.add_argument("--voice", help="speech voice/model name, for example en_GB-alba-medium or Daniel")
    parser.add_argument("--rate", type=int, default=0, help="speech rate; backend default when omitted")
    parser.add_argument("--volume", type=int, default=160, help="espeak-ng volume or Piper gain percent, ignored by macOS say")
    parser.add_argument("--audio-device", help="ALSA device for aplay, for example plughw:1,0")
    parser.add_argument(
        "--piper-python",
        default="",
        help="Python executable with piper-tts installed; defaults to /opt/speaking-clock/venv/bin/python when present",
    )
    parser.add_argument("--piper-data-dir", default="/opt/speaking-clock/voices", help="Piper voice model directory")
    parser.add_argument("--piper-length-scale", type=positive_float, default=1.0, help="Piper speech length scale")
    parser.add_argument("--piper-noise-scale", type=positive_float, default=0.667, help="Piper noise scale")
    parser.add_argument("--piper-noise-w-scale", type=positive_float, default=0.8, help="Piper phoneme duration noise scale")
    parser.add_argument("--piper-sentence-silence", type=positive_float, default=0.0, help="Piper silence after each sentence")
    parser.add_argument("--piper-url", default="", help="Piper HTTP synthesis URL; when set, avoids reloading the model")
    parser.add_argument("--piper-timeout", type=positive_float, default=20.0, help="Piper HTTP synthesis timeout in seconds")
    parser.add_argument(
        "--piper-startup-timeout",
        type=positive_float,
        default=120.0,
        help="seconds to wait for Piper HTTP to become ready; 0 waits forever",
    )

    parser.add_argument("--require-sync", action="store_true", help="wait until the system clock reports NTP sync")
    parser.add_argument(
        "--sync-timeout",
        type=positive_float,
        default=0.0,
        help="seconds to wait for sync; 0 waits forever",
    )
    parser.add_argument(
        "--min-notice",
        type=positive_float,
        default=4.0,
        help="minimum seconds before the target boundary when choosing an announcement",
    )
    parser.add_argument(
        "--schedule-margin",
        type=positive_float,
        default=0.25,
        help="extra scheduling safety before speech starts",
    )
    parser.add_argument(
        "--gap-before-strokes",
        type=positive_float,
        default=0.45,
        help="silence between the spoken sentence and first stroke",
    )
    parser.add_argument(
        "--playback-latency",
        type=float,
        default=0.0,
        help="seconds to start strokes early to compensate for player latency",
    )

    parser.add_argument("--stroke-frequency", type=float, default=1000.0)
    parser.add_argument("--stroke-duration", type=positive_float, default=0.12)
    parser.add_argument("--stroke-sample-rate", type=int, default=8000)
    parser.add_argument("--stroke-amplitude", type=float, default=0.45)
    parser.add_argument(
        "--log-level",
        choices=("DEBUG", "INFO", "WARNING", "ERROR"),
        default=os.environ.get("SPEAKING_CLOCK_LOG_LEVEL", "INFO"),
    )

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    logging.basicConfig(
        level=getattr(logging, args.log_level),
        format="%(asctime)s %(levelname)s %(message)s",
    )

    try:
        if args.dry_run:
            engine = SpeechEngine(
                backend="dry-run",
                voice=None,
                rate=args.rate or 140,
                volume=args.volume,
                default_voice=False,
            )
            player = None
        else:
            engine = select_speech_engine(args)
            player = select_audio_player(args)

        LOG.info(
            "using speech backend %s%s and player %s",
            engine.backend,
            f" voice={engine.voice}" if engine.voice else "",
            player.player if player else "none",
        )

        if args.test_time:
            play_test_announcement(args, engine, player)
        else:
            run_clock(args, engine, player)
        return 0
    except KeyboardInterrupt:
        return 130
    except ClockError as exc:
        print(f"speaking-clock: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
