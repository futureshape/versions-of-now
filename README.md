# Versions of Now

This repository contains simulations and ESPHome firmware for a collection of
clock displays. The installation is intended to grow across multiple display
types, while keeping each clock easy to reason about, preview, and flash.

## Repository Layout

```text
simulator/
  HTML-only display simulations for designing layouts and animations.

esphome/
  ESPHome device configurations for physical clocks.

esphome/shared/
  Shared ESPHome package fragments used by multiple clocks.

esphome/fonts/
  Local bitmap fonts used by ESPHome display rendering.
```

## Current Clocks

### 8x32 Dot Matrix Clock

- Simulator: `simulator/8x32-dot-matrix-clock.html`
- ESPHome config: `esphome/8x32-dot-matrix-clock.yaml`
- Display platform: `max7219digit`
- Time source: NTP via shared ESPHome config
- Network UI: password-protected ESPHome web server
- Home Assistant: intentionally not configured

The display shows `HH:MMSS` on an 8x32 LED matrix. Seconds use a one-by-one
pixel swap animation, while minute changes use a falling-pixel transition.

### CRT BBC Clock

- Simulator: `simulator/crt-bbc-clock.html`
- ESPHome config: `esphome/crt-bbc-clock.yaml`
- Display platform: ESP32 composite video on GPIO25 DAC
- Video library: vendored `aquaticus/esp32_composite_video_lib`
- Time source: NTP via shared ESPHome config
- Home Assistant: intentionally not configured

The display renders a black-and-white BBC-style mechanical clock ident for
EMF26 on PAL composite video. See `docs/CRT_BBC_CLOCK.md` for hardware and
library notes.

### PCD8544 Swatch Internet Time Clock

- ESPHome config: `esphome/nokia-beats-clock.yaml`
- Display platform: `pcd8544`
- Time source: NTP via shared ESPHome config
- Home Assistant: intentionally not configured

The display shows Swatch Internet Time as `@xxx` on an 84x48 Nokia 5110-style
LCD, with a small `SWATCH INTERNET TIME` label. See
`docs/PCD8544_SWATCH_INTERNET_TIME_CLOCK.md` for hardware, font, and beat
calculation notes.

### Flip Digits Clock

- ESPHome config: `esphome/flpidigits-clock.yaml`
- Display platform: four FlipDigitSSB seven-segment controllers over RS485
- Time source: NTP via shared ESPHome config
- Home Assistant: intentionally not configured

The display shows local `HHMM` time on four flip-digit seven-segment modules
driven through a MAX485-based TTL serial to RS485 transceiver. See
`docs/FLPIDIGITS_CLOCK.md` for protocol, wiring, and address notes.

## Development Workflow

1. Prototype display layout and animation in `simulator/`.
2. Keep each simulator as a single HTML file so it can be opened directly.
3. Port the chosen behavior to an ESPHome YAML file in `esphome/`.
4. Keep reusable network, time, OTA, and web-server settings in
   `esphome/shared/`.
5. Validate ESPHome changes before flashing:

```sh
esphome config esphome/<clock-name>.yaml
```

For larger changes, also compile:

```sh
esphome compile esphome/<clock-name>.yaml
```

## ESPHome Conventions

- Prefer `esp-idf` for ESP32 devices.
- Do not enable Home Assistant API or MQTT unless the project explicitly needs
  it.
- Do not configure Wi-Fi AP fallback for installation clocks.
- Do enable OTA with a password from shared config.
- Do enable the ESPHome web server with shared password protection when useful
  for local configuration.
- Get wall-clock time from NTP through shared config.
- Make board names, display platforms, and hardware pins explicit in each
  device YAML.

## Fonts

Use local bitmap fonts for small LED matrix text. Font files should live in
`esphome/fonts/`, and their source/license should be documented in that folder.

The current startup/debug font is a public-domain 5x7 BDF from
`IT-Studio-Rech/bdf-fonts`.

## Shared Configuration

`esphome/shared/network.yaml` currently centralizes:

- Wi-Fi credentials
- Web-server authentication
- OTA password
- NTP time source
- Timezone

Device-specific YAML files should include it with:

```yaml
packages:
  network: !include shared/network.yaml
```

If a future clock needs different credentials or timezone behavior, override the
substitutions in that device YAML rather than duplicating the shared package.
