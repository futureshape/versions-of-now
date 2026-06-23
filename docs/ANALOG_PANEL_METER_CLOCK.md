# Analog Panel Meter Clock

ESPHome config: `esphome/analog-panel-meter-clock.yaml`

This clock drives two analog panel meters from an MCP4728 quad DAC. The hour
meter uses channel A and the minute meter uses channel B; channels C and D are
left unused.

## Hardware

- Controller: ESP32 DevKit-style board.
- DAC: MCP4728 on I2C address `0x60`.
- I2C pins: GPIO21 SDA, GPIO22 SCL by default.
- Meter outputs: MCP4728 channel A for hours, channel B for minutes.
- Output span: 0-5 V when the MCP4728 VDD/reference is a regulated 5 V supply.
- Status LED: GPIO2, if the ESP32 board exposes a controllable LED there.

Tie the ESP32 ground, MCP4728 ground, and panel-meter signal ground together.
The ESP32 I2C pins are 3.3 V logic; if the DAC is powered at 5 V, use a proper
I2C level shifter or a module whose inputs are confirmed to accept 3.3 V highs
while producing a 5 V DAC span.

Panel meters should be high-impedance voltage inputs. If a meter loads the DAC
output enough to affect the reading, add a buffer stage between the MCP4728 and
the meter.

## Time Mapping

The hour meter behaves like a 12-hour analog clock hand:

```text
((hour mod 12) * 3600 + minute * 60 + second + fraction) / 43200
```

The minute meter behaves like a minute hand:

```text
(minute * 60 + second + fraction) / 3600
```

ESPHome provides wall-clock time at one-second resolution. The firmware observes
each second tick and uses `millis()` to interpolate within that second, then
writes only when the calculated 12-bit DAC code changes.

With a full 0-5 V span, the MCP4728's 12-bit output gives about one new minute
meter DAC step every 0.88 seconds, and about one new hour meter DAC step every
10.55 seconds. The update interval is 100 ms so the firmware catches each
available DAC step promptly without churning the I2C bus unnecessarily.

Both meters wrap to zero at the top of their cycle, just like clock hands
passing 12.

## Startup And Controls

While Wi-Fi is not connected, the hour meter sits at zero and the minute meter
sweeps. While Wi-Fi is connected but NTP time is not valid yet, the hour meter
sits at quarter scale and the minute meter continues sweeping.

The ESPHome web UI exposes:

- `Meter Mode`: `Clock`, `Zero`, `Half Scale`, `Full Scale`, and `Sweep`.
- `Hour Meter Zero Level` and `Hour Meter Full Scale Level`.
- `Minute Meter Zero Level` and `Minute Meter Full Scale Level`.

The zero/full-scale sliders are percentages of the DAC span. They can be used
to trim physical meter calibration, limit travel, or intentionally invert a
meter by setting full scale lower than zero.

The MCP4728 is configured with `store_in_eeprom: false`; continuous clock
movement should update the volatile DAC registers only.
