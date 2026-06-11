# Pico ePaper Clock

This clock pairs `simulator/pico-epaper-clock.html` with a Raspberry Pi Pico W
running ESPHome and a Waveshare Pico-ePaper-4.2 black/white display.

## Hardware Assumptions

- Controller board: Raspberry Pi Pico W, ESPHome `rp2040` platform.
- Display: Waveshare Pico-ePaper-4.2, 4.2 inch, 400x300, black/white.
- ESPHome display platform: local custom component `pico_epaper_4in2_v2`.
- Bus: 4-wire SPI with DIN/MOSI, CLK/SCK, CS, DC, RST, and BUSY.

Default wiring comes from the Waveshare Pico-ePaper-4.2 hardware connection
table:

```text
Pico-ePaper-4.2  Pico W
VCC              VSYS
GND              GND
DIN              GP11
CLK              GP10
CS               GP9
DC               GP8
RST              GP12
BUSY             GP13
```

The board is treated as a black/white panel. Waveshare's official demo for this
board uses the `EPD_4in2_V2` driver, which also exposes 4-gray and partial
refresh entry points. The first ESPHome implementation intentionally keeps only
the black/white full-refresh path so it can be compared directly against the
working demo code.

## Behavior

The clock renders local time in Caveat Bold from Google Fonts: large `HH:MM`
near the center of the panel, with smaller seconds underneath.

The custom display component has `update_interval: never`; an ESPHome interval
checks the shared SNTP time once per second. Second changes use partial refresh;
minute changes force a full refresh to keep the panel clean. During startup,
compact diagnostics show Wi-Fi and time-sync status, with diagnostic refreshes
limited to once per minute.

The local `pico_epaper_4in2_v2` component lives under
`esphome/components/pico_epaper_4in2_v2/` and is loaded with ESPHome
`external_components`. It follows the Waveshare `EPD_4in2_V2` black/white
command sequence:

- Reset high/low/high with the demo timings.
- Soft reset with command `0x12`.
- Configure display update control, border waveform, data entry mode, full
  400x300 RAM window, and cursor position.
- Full refresh: send the same 1-bit framebuffer to commands `0x24` and `0x26`,
  then refresh with command `0x22` data `0xF7`, followed by command `0x20`.
- Partial refresh: send a fixed byte-aligned seconds window to command `0x24`,
  then refresh with command `0x22` data `0xFF`, followed by command `0x20`.
  This mirrors the Waveshare demo's approach more closely than a dynamic
  full-framebuffer diff.

ESPHome's built-in `waveshare_epaper` 4.2 inch models use different command
paths, including the older 4.2 inch sequence and the `EPD_4in2b_V2` B/R/BWR
sequence. Those did not match the demo that worked on this hardware.

Unlike the ESP32 clocks, this Pico W config uses `shared/network-no-web.yaml`.
It keeps Wi-Fi, OTA, and SNTP, but deliberately omits `web_server` so the RP2040
Arduino build does not pull in `ESPAsyncWebServer` and its extra PlatformIO
platform dependency checks.

Future handwriting-font rotation should be added as a small set of alternate
font definitions and an explicit selection strategy. For now, Caveat is the only
font family.

## Sources

- Waveshare Pico-ePaper-4.2 wiki:
  https://www.waveshare.com/wiki/Pico-ePaper-4.2
- Waveshare `EPD_4in2_V2` demo driver:
  https://github.com/waveshareteam/Pico_ePaper_Code/tree/main/c/lib/e-Paper
- ESPHome Waveshare e-paper display component:
  https://esphome.io/components/display/waveshare_epaper/
- ESPHome RP2040 platform:
  https://esphome.io/components/rp2040/

## Validation

Validate the config before flashing:

```sh
esphome config esphome/pico-epaper-clock.yaml
```

Compile before flashing because this clock uses RP2040, a Waveshare e-paper
display, and a Google Font:

```sh
esphome compile esphome/pico-epaper-clock.yaml
```
