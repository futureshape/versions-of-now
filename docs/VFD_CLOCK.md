# VFD Clock

This clock drives a Wincor Nixdorf BA63 customer display directly from
ESPHome over serial.

## Hardware

- Display: BA63 vacuum fluorescent customer display.
- Display geometry: 2 lines, 20 alphanumeric characters per line.
- ESPHome config: `esphome/vfd-clock.yaml`.
- ESP32 serial pin: GPIO17 TX by default. The current firmware does not read
  from the display, so no ESP32 RX pin is required.
- Serial settings: 9600 baud, 8 data bits, odd parity, 1 stop bit.
- Electrical interface: the BA63 is RS232, not 3.3 V TTL UART. Use a proper
  TTL-to-RS232 level shifter such as a MAX3232-style board between the ESP32
  and the display.
- Power: BA63 units expect their own display supply; many RS232 BA63 cables
  carry 12 V DC in the original POS wiring.

## Jumper Settings

The RS232 BA63 uses solderable wire jumpers on the display circuitry for serial
parameters and self-test mode. For this ESPHome config, use the factory-style
settings: JP1 OUT, JP2 OUT, JP3 IN, JP4 IN, JP5 OUT.

| Jumper | Position | Behaviour |
| --- | --- | --- |
| JP1 OUT, JP2 OUT | 9600 baud | Matches `ba63_baud_rate` in `vfd-clock.yaml`. |
| JP1 IN, JP2 OUT | 4800 baud | Requires matching the ESPHome UART baud rate. |
| JP1 OUT, JP2 IN | 2400 baud | Requires matching the ESPHome UART baud rate. |
| JP1 IN, JP2 IN | 1200 baud | Requires matching the ESPHome UART baud rate. |
| JP3 IN | Parity on | Matches this config. |
| JP3 OUT | Parity off | Do not use with the current `parity: ODD` config. |
| JP4 IN | Odd parity | Matches this config when JP3 is IN. |
| JP4 OUT | Even parity | Requires changing the ESPHome UART parity. |
| JP5 IN | Self-test | Display test mode; not normal serial display operation. |
| JP5 OUT | Normal operation | Matches this clock firmware. |

The manual shows JP1 through JP5 becoming accessible after removing the front
plate by releasing the exterior housing clips beneath it.

## Startup Sequence

The display intentionally uses the simple normal sequence requested for the
first version:

1. `CONNECTING TO WIFI` while Wi-Fi is not associated.
2. `IP ADDRESS` plus the assigned station IP once Wi-Fi is connected.
3. `HH:MM:SS` on the first line once SNTP has produced valid local time, with
   a 20-character seconds progress bar on the second line.

The seconds bar uses the existing BA63 character set. Each column represents
three seconds, moving through space, `-`, `=`, then raw display byte `0xF0`
for the filled/triple-equals cell before the next column starts.

The ESPHome web UI exposes a `Display Enabled` switch and `Refresh Display`
button. Turning the display off sends the BA63 clear-display command once.

## Protocol Notes

The BA63 uses a subset of VT100-style control sequences. This config only uses:

- `ESC [2J` to clear the display.
- `ESC [1;1H` to move the cursor to line 1, column 1.
- `ESC [2;1H` to move the cursor to line 2, column 1.

Each displayed row is written as exactly 20 characters padded with spaces, so
shorter status text clears any previous longer text without relying on
line-clearing commands.

References:

- Wincor Nixdorf BA63 product manual:
  https://www.manualslib.com/manual/1146241/Wincor-Nixdorf-Ba63.html
- BA63/BA66 serial parity notes from `anachrocomputer/ba63gui`:
  https://github.com/anachrocomputer/ba63gui
