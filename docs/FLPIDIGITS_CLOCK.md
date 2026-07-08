# Flip Digits Clock

ESPHome config: `esphome/flpidigits-clock.yaml`

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
the seven controlled segments as top-to-bottom, so the ESPHome config keeps the
digit segment table in one small `SEGMENTS_FOR_DIGIT` array. If the physical
digits render scrambled numbers, adjust that table rather than changing the
time logic.

## Defaults

- Baud rate: `57600`
- Left-to-right digit addresses: `0`, `1`, `2`, `3`
- UART pins: `GPIO17` TX and `GPIO16` RX
- Time source: shared SNTP config

Startup diagnostics are intentionally compact because the display can only show
digits and segment patterns:

- `0123`: addressed module check. Each digit is commanded by its own address and
  should show that address.
- `----`: Wi-Fi is still connecting or no IPv4 address is available yet.
- ` 192`, ` 168`, ` 001`, etc.: IPv4 octets rotate one at a time with the first
  digit blank and the octet zero-padded across the remaining three digits. The
  clock keeps rotating the IP address until SNTP time is valid.
- Current `HHMM`: valid local time is available after the startup IP display.

The ESPHome web server exposes controls to refresh the display, show all
segments, show dashes, and blank/re-enable the display.
