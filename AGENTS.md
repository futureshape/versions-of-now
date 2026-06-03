# AI Coding Agent Rules

These rules apply to coding agents working in this repository.

## Project Intent

This repo supports an installation of physical clocks. It has two connected
surfaces:

- `simulator/`: browser-based prototypes for display layout and animation.
- `esphome/`: ESPHome configurations for real ESP32-based clocks.

Future clocks may use different display platforms. Do not assume every clock is
a MAX7219 dot matrix display.

## General Rules

- Read the existing simulator and ESPHome config before making changes.
- Keep changes scoped to the requested clock or shared package.
- Preserve user changes and do not revert unrelated edits.
- Prefer simple, explicit code over clever abstractions.
- Add documentation when introducing a new display type, font, shared package,
  or hardware assumption.
- Do not add Home Assistant API, MQTT, Wi-Fi AP fallback, cloud dependencies, or
  new frameworks unless the user asks for them.

## Simulators

- Keep each simulator as a single HTML file.
- Name simulator files after the display/clock they contain.
- Build the actual simulation as the main screen.
- Include controls for manual animation triggers and useful timing parameters.
- Keep glyphs and display geometry easy to edit in JavaScript.
- Keep animation logic close enough to ESPHome constraints that it can be ported
  to MCU code.
- Avoid adding build tooling for simulators unless explicitly requested.

## ESPHome

- Prefer ESPHome YAML files named to match their simulator.
- Include shared network/time/web/OTA settings with:

```yaml
packages:
  network: !include shared/network.yaml
```

- Prefer `esp-idf` for ESP32 configs.
- Keep board type, display platform, and pins explicit in each device YAML.
- Keep NTP and timezone in shared config unless there is a device-specific need.
- Keep OTA password and web-server password in shared config.
- Do not add AP fallback.
- Do not add Home Assistant API or MQTT by default.
- Use `logger:` when local serial/log debugging is useful.
- Remove temporary high-frequency debug logs before finishing.

## Display Lambdas And MCU Constraints

Display lambdas should be bounded and predictable:

- Use fixed-size buffers sized to the display.
- Avoid dynamic allocation and unbounded containers inside display lambdas.
- Avoid expensive per-frame string processing.
- Prefer integer math where it keeps the code readable.
- Keep pseudo-random animation deterministic when possible.
- Keep state names descriptive: avoid names tied only to minutes if the value
  tracks seconds or full time.
- Comment compactly around hardware assumptions and non-obvious animation state.

## Fonts And Assets

- Prefer local bitmap fonts for tiny LED displays.
- Do not use Google Fonts for MAX7219-style 8-pixel display text.
- Put ESPHome fonts in `esphome/fonts/`.
- Document font source and license in `esphome/fonts/README.md`.
- Subset glyphs in ESPHome font configs when only a few characters are needed.

## Verification

Run the smallest useful verification for the change:

```sh
esphome config esphome/<clock-name>.yaml
```

For display lambda, board, framework, dependency, or platform changes, also run:

```sh
esphome compile esphome/<clock-name>.yaml
```

If verification cannot be run, say why in the final response.
