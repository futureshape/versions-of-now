# TM1637 6-Digit Clock

ESPHome config: `esphome/tm1637-clock.yaml`

This clock uses a six-digit TM1637 seven-segment module driven directly from an
ESP32-S3 DevKitC-1 N16R8-class board. It shows local NTP time as `HHMMSS`; dots
separate hours, minutes, and seconds.

The ESPHome board profile is `esp32-s3-devkitc1-n16r8`, with 16 MB flash and
8 MB octal PSRAM configured explicitly. If the installed module has a different
marking, keep the S3-safe TM1637 pins but update the board/flash/PSRAM settings
to match the actual module.

## Wiring

Default pins:

- CLK: `GPIO16`
- DIO: `GPIO17`
- VCC: `3V3`
- GND: `GND`

The ESPHome TM1637 component bit-bangs CLK and DIO, so the pins can be moved to
other general-purpose ESP32-S3 GPIOs through substitutions in the YAML. Avoid
S3 strapping pins, USB-Serial-JTAG pins, and flash/PSRAM pins unless the
hardware has been checked.

Power the module from 3.3 V by default. Some TM1637 boards have pull-ups to VCC
on CLK/DIO, which can put 5 V on ESP32 GPIOs if the module is powered from 5 V.
Use level shifting or confirm the board's pull-up arrangement before using 5 V.

## Startup Display

While Wi-Fi is disconnected, the display shows six dashes.

After Wi-Fi connects, the assigned IPv4 address is shown as two six-digit
screens with each octet zero-padded to three digits and a dot between the two
octets:

- `192.168.1.42` screen 1: `192.168`
- `192.168.1.42` screen 2: `001.042`

The IP screens cycle during the startup debug window and continue if SNTP time
is not valid yet. Once local time is valid and the startup window has elapsed,
the display switches to `HH.MM.SS`.
