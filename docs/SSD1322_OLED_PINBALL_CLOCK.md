# SSD1322 OLED Pinball Clock

This clock ports `simulator/256x64-oled-pinball-clock.html` to an ESP32 driving
a 256x64 SSD1322 OLED over 4-wire SPI.

## Hardware Assumptions

- Display controller: SSD1322.
- Display geometry: 256x64.
- Bus: 4-wire SPI with CLK, DIN/MOSI, CS, and DC.
- Default board: ESP32 DevKit-style board using ESP32 VSPI pins.
- Default wiring in `esphome/256x64-oled-pinball-clock.yaml`, matching the
  known-good `gadec-uk/departures-board` SSD1322 wiring:
  - CLK: GPIO18
  - DIN/MOSI: GPIO23
  - DC: GPIO5
  - CS: GPIO26

Many SSD1322 modules ship configured for 8-bit 80XX mode. This clock assumes
the module has been changed to 4-wire SPI mode before flashing.

The SSD1322 can render grayscale, but this clock intentionally uses the display
as a 1-bit on/off framebuffer to match the simulator direction and reduce OLED
burn-in risk.

## Behavior

The time is drawn with an embedded 5x7 bitmap digit font scaled to 4x. It moves
inside the display bounds and bounces off the screen edges. Floating objects
stream in from off-screen, collide with the moving time body, and can be knocked
back off-screen before new objects spawn. The trail is stored as a fixed
256x64 byte buffer where each non-zero byte is rendered as an on pixel; old
trail pixels erode into sparse stardust rather than grayscale fading.

During startup, the OLED shows compact Wi-Fi and NTP diagnostics before the
clock animation starts.

## Validation

Validate the config before flashing:

```sh
esphome config esphome/256x64-oled-pinball-clock.yaml
```

Compile before flashing because this clock uses a custom display lambda:

```sh
esphome compile esphome/256x64-oled-pinball-clock.yaml
```
