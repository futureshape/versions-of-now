# PCD8544 Swatch Internet Time Clock

ESPHome config: `esphome/nokia-beats-clock.yaml`

This clock targets a PCD8544 / Nokia 5110-style 84x48 monochrome LCD over
4-wire SPI. The default pins follow a classic ESP32 DevKit VSPI layout:

- CLK: GPIO18
- DIN / MOSI: GPIO23
- CS / CE: GPIO5
- DC: GPIO25
- RST: GPIO26
- Status LED: GPIO2, if the board exposes a controllable LED there

The PCD8544 backlight is module-specific. Many boards let `LIGHT` be tied to
ground for always-on backlight; add a device-local output or light component if
the installed module wires that pin to a GPIO.

LCD contrast is initialized with ESPHome's native `contrast:` option via the
`display_contrast` substitution, then exposed as a web-server slider named
`LCD Contrast`. The slider value is restored after reboot and applied on the
first display update. PCD8544 modules vary quite a bit, so tune it on the
running device if the default `96` is too faint or too dark.

## Display Layout

The main value is formatted as `@xxx`, where `xxx` is the integer Swatch
Internet Time beat from `000` to `999`. The bottom of the LCD carries the small
two-line label:

```text
SWATCH
INTERNET TIME
```

Uppercase label text is intentional: it is clearer on the existing 5x7 bitmap
font at this display size.

During startup the LCD shows compact diagnostics:

```text
WIFI
CONNECTING
```

Once Wi-Fi is connected but NTP has not produced a valid timestamp yet, it
shows the Wi-Fi status, station IP address, and NTP status:

```text
WIFI OK
192.168.1.23
NTP SYNC
```

## Time Calculation

Swatch Internet Time is based on Biel Mean Time, which is UTC+1 with no daylight
saving adjustment. The display lambda uses the NTP epoch timestamp directly, so
the calculation remains UTC-based even though the shared ESPHome package also
sets a local timezone for other clocks.

The integer beat is:

```text
((utc_seconds_since_midnight + 3600) mod 86400) * 1000 / 86400
```

## Fonts

The large beat text uses Orbitron SemiBold from Google Fonts through ESPHome's
`gfonts` support. Orbitron's geometric numerals suit the clock-like `@xxx`
readout; the configured size leaves room for the two-line label on the 84x48
LCD.

The small label uses the repository's local public-domain `5x7.bdf` bitmap font
so the supporting text stays crisp on the 1-bit LCD.
