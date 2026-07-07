# Panel Meter Scale SVG Generator

Use `tools/panel_meter_scale_svg.py` to generate a print-scale SVG dial legend
for an analog panel meter. The generator uses millimetres for all dimensions, so
the SVG can be printed at 100% scale.

## Accurate Measurement Workflow

Do not trace a photo for geometry unless there is no other option. Photos add
perspective and lens distortion. Use the photo for style, then measure the real
dial with calipers.

Use one consistent origin, normally the top-left corner of the printed face:

- Face width and height.
- Needle pivot / scale centre `x` and `y`, if you can identify it.
- Tick outer radius from the pivot to the outer end of the ticks.
- Start and end tick angles, or start and end tick coordinates.
- Minor, medium, and major tick lengths and stroke widths.
- Label radius, font size, and any per-label nudges.
- Screw hole positions and diameters if you want cut or registration guides.

If the pivot is hidden, measure three points on the same tick arc: the min tick
outer end, a middle/top tick outer end, and the max tick outer end. Put them in
`scale.arc_points_mm`; the script will fit the circle and derive the centre and
radius. The first and third points are also used as the start and end angles
unless `start_point_mm` and `end_point_mm` are supplied.

## Finding The Pivot Accurately

The pivot is the centre of the circle that the tick arc lies on. It may be below
the visible face opening, so measuring the visible artwork is often more useful
than trying to see the needle shaft.

Best practical methods:

- If the mechanical pivot or needle axle is visible, measure its `x` and `y`
  from the same origin as the artwork, usually the top-left corner of the dial
  plate. Remove the front lens if possible; measuring through glass adds
  parallax error.
- If the pivot is hidden, measure three outer tick-end points on the same arc:
  one near the left end, one near the top/middle, and one near the right end.
  Use the same feature each time, for example the centre of the outer end of the
  tick, not sometimes the inner end and sometimes the outer end.
- Choose points that are far apart. Three adjacent ticks produce a noisy centre;
  left/top/right or left/mid/right is much better.
- Repeat with several sets of three points, such as 0/50/100, 10/50/90, and
  20/60/80. The fitted centres should cluster. If they differ by more than about
  0.3-0.5 mm on a small meter face, re-check the point measurements.
- If working from a scan, scan flat at 600 dpi or higher with a ruler included.
  De-skew the image, calibrate pixels per mm from the ruler or known face width,
  then click the tick points. Avoid phone photos unless you correct perspective
  first.
- A manual geometry check is useful: draw a chord between two measured tick
  points, then draw that chord's perpendicular bisector. Do the same for another
  chord. The bisectors intersect at the pivot.
- After fitting the pivot, generate an SVG with `--show-guides`, print it on
  transparency or plain paper at 100%, and overlay it on the original. The guide
  circle should pass through all measured outer tick ends.

For hidden pivots, this JSON is the easiest starting point:

```json
{
  "scale": {
    "arc_points_mm": [
      [12.4, 45.8],
      [74.0, 22.6],
      [135.7, 45.8]
    ]
  }
}
```

Replace those three `[x, y]` pairs with your measured tick-arc points. The
script calculates `center_x_mm`, `center_y_mm`, and `radius_mm` from them.

## Generate The Example

```sh
python3 tools/panel_meter_scale_svg.py \
  --config tools/panel-meter-scale.hours.json \
  --out /tmp/panel-meter-scale.svg
```

For a different scale without editing JSON:

```sh
python3 tools/panel_meter_scale_svg.py \
  --config tools/panel-meter-scale.hours.json \
  --out /tmp/24-hour-panel-meter-scale.svg \
  --min-value 0 \
  --max-value 24 \
  --minor-step 1 \
  --medium-step 6 \
  --major-step 6 \
  --label-values 0,6,12,18,24 \
  --unit h
```

## Fonts

Set the default SVG font family with the top-level `font.family` value:

```json
{
  "font": {
    "family": "Helvetica, Arial, sans-serif"
  }
}
```

Labels, unit text, and extra text inherit that font. You can override specific
sections with `labels.font_family`, `unit.font_family`, or an individual
`extra_text` item's `font_family`.

You can also override the default from the command line:

```sh
python3 tools/panel_meter_scale_svg.py \
  --config tools/panel-meter-scale.hours.json \
  --out /tmp/panel-meter-scale.svg \
  --font-family "DIN Alternate, Helvetica, Arial, sans-serif"
```

To see the construction geometry:

```sh
python3 tools/panel_meter_scale_svg.py \
  --config tools/panel-meter-scale.hours.json \
  --out /tmp/panel-meter-scale-guides.svg \
  --show-guides
```

## Printing

Print at 100% scale with "fit to page" disabled. Measure the printed width,
height, and tick span before committing to the final material. If the print shop
or editor substitutes fonts, convert text to paths in Inkscape, Illustrator, or
similar software after choosing the final font.
