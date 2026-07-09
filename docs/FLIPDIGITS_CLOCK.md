# Flip Digits Clock

ESPHome config: `esphome/flipdigits-clock.yaml`

This clock drives four FlipDigitSSB seven-segment digit controllers as an
`HH:MM` display over an RS485 bus.

## Hardware

- ESP32 DevKit-style board.
- MAX485-based RS485 transceiver board with TTL serial on the ESP32 side.
- Four FlipDigitSSB one-inch seven-segment display controllers.
- Display supply: 19V DC to 24V DC, per `docs/FlipDigitSSB_rel2.pdf`.

The config assumes the transceiver board handles RS485 direction automatically
and exposes only `RXD` and `TXD` TTL serial pins. Connect ESP32 `GPIO17` to the
transceiver `RXD`, ESP32 `GPIO16` to transceiver `TXD`, and share ground. If the
board exposes separate DE/RE direction pins, add the appropriate ESPHome UART
flow-control pin before flashing.

## Protocol

The protocol document describes five-byte display frames:

```text
0x80, command, address, data, 0x8F
```

The clock uses command `0x89`, which sends one data byte and refreshes the
digit immediately. Address `255` is broadcast, so the four digit addresses
should be unique values from `0` to `254`.

The display byte uses bits `B6..B0`; the MSB is ignored. The document describes
the seven controlled segments as top-to-bottom, but the actual modules were
calibrated with the ESPHome web server's `Walk Raw Segments` button:

```text
B6 middle,
B5 upper-left, B4 lower-left, B3 bottom,
B2 lower-right, B1 upper-right, B0 top
```

In other words, the middle dash is first, then the remaining segments run from
upper-left counter-clockwise around the outside. If another batch of digits
renders scrambled numbers, use `Walk Raw Segments` to show bits `B6` down to
`B0`, then adjust the `SEGMENTS_FOR_DIGIT` table rather than changing the time
logic.

## Defaults

- Baud rate: `57600`
- Logical left-to-right digit addresses: `2`, `3`, `0`, `1`
- UART pins: `GPIO17` TX and `GPIO16` RX
- Time source: shared SNTP config

The modules are physically mounted left-to-right as addresses `2`, `3`, `0`,
`1`. The firmware keeps all display patterns in logical left-to-right order and
applies that address map when sending frames, so the correction applies to
startup diagnostics, IP address octets, time, and manual test patterns.

Startup diagnostics are intentionally compact because the display can only show
digits and segment patterns:

- `0123`: software-corrected position check. The display should read left to
  right even though the mounted physical address order is `2`, `3`, `0`, `1`.
- `----`: Wi-Fi is still connecting or no IPv4 address is available yet.
- ` 192`, ` 168`, ` 001`, etc.: IPv4 octets rotate one at a time with the first
  digit blank and the octet zero-padded across the remaining three digits. The
  clock keeps rotating the IP address until SNTP time is valid.
- Current `HHMM`: valid local time is available after the startup IP display.

The ESPHome web server exposes controls to refresh the display, show all
segments, show dashes, walk the raw segment bits, and blank/re-enable the
display.
