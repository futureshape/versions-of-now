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

| OLED pin | OLED signal | ESP32 connection |
| --- | --- | --- |
| 1 | VSS | GND |
| 2 | VCC_IN | Display power input |
| 4 | D0/CLK | GPIO18 / SPI CLK |
| 5 | D1/DIN | GPIO23 / SPI MOSI |
| 14 | D/C# | GPIO5 |
| 16 | CS# | GPIO26 |

`RESET` is not connected in the current clock wiring.

Many SSD1322 modules ship configured for 8-bit 80XX mode. This clock assumes
the module has been changed to 4-wire SPI mode before flashing.

The SSD1322 renders this clock with 4-bit grayscale. The moving time body is
written at full brightness, while older trail pixels fade down through the
controller's 15 visible gray levels before being erased.

## Behavior

The time is drawn with an embedded 5x7 bitmap digit font scaled to 4x. It moves
inside the display bounds and bounces off the screen edges. Floating objects
stream in from off-screen, collide with the moving time body, and can be knocked
back off-screen before new objects spawn. The trail is stored as a fixed
256x64 byte buffer of remaining lifetime values; each value is mapped to an
SSD1322 grayscale level during rendering. Old trail pixels both dim and erode
into sparse stardust.

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
