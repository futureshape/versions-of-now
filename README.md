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

rpi/
  Raspberry Pi based clock installs and provisioning scripts.

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

### 256x64 OLED Pinball Clock

- Simulator: `simulator/256x64-oled-pinball-clock.html`
- ESPHome config: `esphome/256x64-oled-pinball-clock.yaml`
- Display platform: `ssd1322_spi`
- Time source: NTP via shared ESPHome config
- Home Assistant: intentionally not configured
- Default display-side wiring: OLED pin 1 `VSS` to GND, pin 2 `VCC_IN` to
  display power, pin 4 `D0/CLK` to GPIO18, pin 5 `D1/DIN` to GPIO23, pin 14
  `D/C#` to GPIO5, and pin 16 `CS#` to GPIO26.

The simulator treats the time as a moving bitmap body inside a 256x64 OLED
framebuffer. The time bounces against the screen edges while floating objects
stream through the scene, get knocked off-screen, and respawn. Short grayscale
pixel trails fade and erode into sparse stardust so crisp OLED text does not
sit in one place. See `docs/SSD1322_OLED_PINBALL_CLOCK.md` for hardware and
firmware notes.

### Pico ePaper Clock

- Simulator: `simulator/pico-epaper-clock.html`
- ESPHome config: `esphome/pico-epaper-clock.yaml`
- Display platform: local custom component `pico_epaper_4in2_v2`
- Controller: Raspberry Pi Pico W via ESPHome `rp2040`
- Time source: NTP via shared ESPHome config
- Network UI: intentionally not configured on this RP2040 clock
- Home Assistant: intentionally not configured

The display shows local time in rotating handwriting fonts from Google Fonts,
with large `HH:MM` and smaller seconds. It uses the Waveshare
Pico-ePaper-4.2 black/white 400x300 panel, partial refreshes seconds, and full
refreshes on minute changes. See `docs/PICO_EPAPER_CLOCK.md` for wiring,
refresh behavior, and firmware notes.

### PCD8544 Swatch Internet Time Clock

- ESPHome config: `esphome/nokia-beats-clock.yaml`
- Display platform: `pcd8544`
- Time source: NTP via shared ESPHome config
- Home Assistant: intentionally not configured

The display shows Swatch Internet Time as `@xxx` on an 84x48 Nokia 5110-style
LCD, with a small `SWATCH INTERNET TIME` label. See
`docs/PCD8544_SWATCH_INTERNET_TIME_CLOCK.md` for hardware, font, and beat
calculation notes.

### TM1637 6-Digit Clock

- ESPHome config: `esphome/tm1637-clock.yaml`
- Controller: ESP32-S3 DevKitC-1 N16R8-class board
- Display platform: `tm1637`
- Time source: NTP via shared ESPHome config
- Home Assistant: intentionally not configured

The display shows local `HHMMSS` time on a six-digit TM1637 seven-segment LED
module, with dots separating hours, minutes, and seconds. It targets an ESP32-S3
board with 16 MB flash and octal PSRAM. On startup it shows the assigned IPv4
address as two zero-padded six-digit screens, with a dot between each octet
pair. See `docs/TM1637_6_DIGIT_CLOCK.md` for wiring and startup-display notes.

### Flip Digits Clock

- ESPHome config: `esphome/flpidigits-clock.yaml`
- Display platform: four FlipDigitSSB seven-segment controllers over RS485
- Time source: NTP via shared ESPHome config
- Home Assistant: intentionally not configured

The display shows local `HHMM` time on four flip-digit seven-segment modules
driven through a MAX485-based TTL serial to RS485 transceiver. See
`docs/FLPIDIGITS_CLOCK.md` for protocol, wiring, and address notes.

### Analog Panel Meter Clock

- ESPHome config: `esphome/analog-panel-meter-clock.yaml`
- Display platform: MCP4728 I2C DAC driving two 0-5 V analog panel meters
- Time source: NTP via shared ESPHome config
- Home Assistant: intentionally not configured

The hour meter uses MCP4728 channel A and moves as a continuous 12-hour clock
hand, including minute and second progress. The minute meter uses channel B and
moves continuously through each hour. See
`docs/ANALOG_PANEL_METER_CLOCK.md` for wiring, calibration, and DAC-resolution
notes.

### VFD Clock

- ESPHome config: `esphome/vfd-clock.yaml`
- Display platform: Wincor Nixdorf BA63 2x20 VFD over RS232 serial
- Time source: NTP via shared ESPHome config
- Home Assistant: intentionally not configured

The display starts with `CONNECTING TO WIFI`, then shows the assigned IP address,
then shows local `HH:MM:SS` on the first line with a seconds progress bar on the
second line once NTP time is valid. See `docs/VFD_CLOCK.md` for BA63 serial
settings, wiring, and control-sequence notes.

For the current ESPHome UART settings, configure the BA63 jumpers as JP1 OUT,
JP2 OUT, JP3 IN, JP4 IN, JP5 OUT: 9600 baud, parity on, odd parity, normal
operation.

### Dali Clock on HyperPixel 4.0 Square

- Raspberry Pi install: `rpi/xdaliclock-hyperpixel-square/`
- Display: Pimoroni HyperPixel 4.0 Square, 720x720 DPI display
- Runtime: Raspberry Pi OS Lite with a minimal X11 session running `xdaliclock`

The Pi boots directly into Jamie Zawinski's native Linux/X11 Dali Clock app.
See `rpi/xdaliclock-hyperpixel-square/README.md` for SD-card setup and
HyperPixel driver notes.

### Speaking Clock

- Raspberry Pi install: `rpi/speaking-clock/`
- Output: system audio output for a vintage telephone handset headset
- Runtime: Python standard library, `espeak-ng`, and ALSA on Raspberry Pi;
  built-in `say` and `afplay` on macOS for testing
- Time source: system clock synchronized by the OS, with the Pi service waiting
  for NTP sync before announcing

The clock announces the local time every 10 seconds with a UK speaking-clock
style phrase and three 1 kHz strokes, scheduling the third stroke on the
announced time. See `rpi/speaking-clock/README.md` for setup and calibration.

## Development Workflow

1. Prototype display layout and animation in `simulator/` (if neceesary, otherwise skip to esphome)
2. Keep each simulator as a single HTML file so it can be opened directly.
3. Port the chosen behavior to an ESPHome YAML file in `esphome/`.
4. Keep reusable network, time, OTA, and web-server settings in
   `esphome/shared/`.
5. For Raspberry Pi clocks, keep each install in `rpi/<clock-name>/` with a
   README and an explicit provisioning script.
6. Validate ESPHome changes before flashing:

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
