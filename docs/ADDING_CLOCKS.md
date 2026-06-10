# Adding Clocks

Use this guide when adding another clock to the installation.

## Naming

Choose names that describe the physical display and clock role.

Examples:

```text
simulator/8x32-dot-matrix-clock.html
esphome/8x32-dot-matrix-clock.yaml
simulator/64x32-rgb-matrix-clock.html
esphome/64x32-rgb-matrix-clock.yaml
simulator/4-digit-seven-segment-clock.html
esphome/4-digit-seven-segment-clock.yaml
rpi/xdaliclock-hyperpixel-square/
```

Keep simulator and ESPHome filenames aligned so it is obvious which prototype
maps to which device.

For Raspberry Pi based clocks, create a folder under `rpi/` named after the
clock/display combination. Include a `README.md` with hardware assumptions and
an installer or provisioning script that can be rerun on a fresh OS image.

## Simulator First

Create or update the simulator before changing firmware behavior. Simulators
should be:

- Single HTML files.
- Openable directly from disk.
- Focused on the usable display, not a marketing page.
- Designed with controls for animation speed, manual triggers, and time testing.
- Clear enough to compare layout and animation against the physical device.

Prefer simple JavaScript data structures for glyphs and framebuffers so they can
be ported to ESPHome C++ lambdas without changing the animation model.

## ESPHome Port

Each device YAML should define:

- `substitutions` for the device name, friendly name, pins, and display-specific
  constants.
- `packages` for shared network/time/web/OTA config.
- The board and framework.
- The display platform and update interval.
- Local controls such as brightness, animation duration, and manual triggers.
- A bounded display lambda or display component configuration.

Use shared package fragments for behavior that will be common to most clocks.
Keep display-specific behavior in the device YAML unless two or more clocks
really share the same implementation.

## Raspberry Pi Installs

Use Raspberry Pi only when a clock genuinely benefits from a Linux display stack
or browser runtime. Keep the installation reproducible:

- Recommend a specific Raspberry Pi OS image family.
- Keep runtime dependencies installed by a script, not by undocumented manual
  package selection.
- Document display overlays, GPIO conflicts, rotation, and network assumptions.
- Use dedicated local users and systemd/autologin configuration for kiosk clocks.
- Keep secrets out of the repository; put Wi-Fi and SSH setup in Raspberry Pi
  Imager or another local provisioning step.
- Prefer built-in kernel overlays over vendor legacy installers when current
  hardware and OS releases support them.

## Animation Guidelines

ESPHome display lambdas run frequently, so animation code should stay small and
bounded:

- Use fixed-size framebuffers and arrays.
- Avoid heap allocation in display lambdas.
- Avoid long loops that scale beyond the display size.
- Prefer deterministic pseudo-random ordering over storing large random tables.
- Keep timing state explicit: displayed time, target time, active animation, and
  animation start timestamp.
- Make manual trigger controls consume requests on the next display frame.
- Remove noisy temporary debug logging once a behavior is understood.

When a display is too constrained to match the simulator exactly, preserve the
intent of the animation rather than chasing perfect pixel-for-pixel parity.

## Display Platform Notes

Different display platforms will have different strengths. Do not force all
clocks into the same rendering model.

- Dot matrix displays can use compact framebuffers and custom bitmap glyphs.
- Seven-segment displays may be better represented as segment states rather than
  pixels.
- RGB matrices may need palettes, brightness limits, and different performance
  checks.
- E-paper or slow-refresh displays should prioritize refresh cadence and ghosting
  behavior over frame animation.

Document display-specific decisions close to the YAML or simulator that uses
them.

## Validation Checklist

Before considering a clock change done:

- Open the simulator and test normal time progression.
- Test manual animation triggers.
- Run `esphome config esphome/<clock-name>.yaml`.
- Compile before flashing when display lambdas or platform settings changed.
- Confirm any new fonts or external assets have source/license notes.
- Confirm shared settings remain shared and device settings remain device-local.
