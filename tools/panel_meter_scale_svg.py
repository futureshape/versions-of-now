#!/usr/bin/env python3
"""Generate a print-scale SVG legend for an analog panel meter.

All dimensions are millimetres. Angles use the usual instrument-dial
convention: 0 degrees points right, 90 degrees points up.
"""

from __future__ import annotations

import argparse
import copy
import json
import math
import sys
from pathlib import Path
from typing import Any
from xml.sax.saxutils import escape, quoteattr


DEFAULT_CONFIG: dict[str, Any] = {
    "page": {
        "width_mm": 148.0,
        "height_mm": 74.0,
        "background": "#f7eedb",
    },
    "font": {
        "family": "Helvetica, Arial, sans-serif",
    },
    "ink": "#24172b",
    "face": {
        "draw_background": True,
        "draw_border": False,
        "border_color": "#9a8f7c",
        "border_width_mm": 0.15,
        "corner_radius_mm": 0.0,
    },
    "scale": {
        "min_value": 0.0,
        "max_value": 100.0,
        "minor_step": 2.0,
        "medium_step": 10.0,
        "major_step": 20.0,
        "center_x_mm": 74.0,
        "center_y_mm": 118.0,
        "radius_mm": 80.0,
        "start_angle_deg": 158.0,
        "end_angle_deg": 22.0,
        "arc_points_mm": [],
        "start_point_mm": None,
        "end_point_mm": None,
        "minor_tick_length_mm": 3.0,
        "medium_tick_length_mm": 5.0,
        "major_tick_length_mm": 8.0,
        "minor_tick_width_mm": 0.22,
        "medium_tick_width_mm": 0.30,
        "major_tick_width_mm": 0.42,
        "tick_color": None,
        "tick_linecap": "butt",
    },
    "labels": {
        "values": None,
        "format": "{:g}",
        "radius_mm": 92.0,
        "font_family": None,
        "font_size_mm": 6.2,
        "font_weight": "400",
        "color": None,
        "angle_offsets_deg": {},
        "radial_offsets_mm": {},
        "x_offsets_mm": {},
        "y_offsets_mm": {},
    },
    "unit": {
        "text": "\u00b0C",
        "x_mm": 74.0,
        "y_mm": 39.0,
        "font_family": None,
        "font_size_mm": 9.0,
        "font_weight": "400",
        "color": None,
    },
    "holes": [],
    "extra_text": [],
    "guides": {
        "show_pivot": False,
        "show_arc_circle": False,
        "show_start_end": False,
        "color": "#0b72b9",
    },
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Generate a parametric SVG scale for an analog panel meter. "
            "All dimensions are in mm."
        )
    )
    parser.add_argument("--config", type=Path, help="JSON config file to merge over defaults")
    parser.add_argument("--out", type=Path, help="Output SVG path. Defaults to stdout")

    parser.add_argument("--width-mm", type=float, help="Face/page width")
    parser.add_argument("--height-mm", type=float, help="Face/page height")
    parser.add_argument("--center-x-mm", type=float, help="Scale centre / needle pivot X")
    parser.add_argument("--center-y-mm", type=float, help="Scale centre / needle pivot Y")
    parser.add_argument("--radius-mm", type=float, help="Tick outer radius")
    parser.add_argument("--start-angle-deg", type=float, help="Angle for min_value tick")
    parser.add_argument("--end-angle-deg", type=float, help="Angle for max_value tick")
    parser.add_argument("--min-value", type=float, help="First scale value")
    parser.add_argument("--max-value", type=float, help="Last scale value")
    parser.add_argument("--minor-step", type=float, help="Minor tick value interval")
    parser.add_argument("--medium-step", type=float, help="Medium tick value interval")
    parser.add_argument("--major-step", type=float, help="Major tick and default label interval")
    parser.add_argument("--label-values", help="Comma-separated label values, e.g. 0,20,40")
    parser.add_argument("--unit", help="Centre unit text")
    parser.add_argument("--font-family", help="SVG font-family for labels and unit text")
    parser.add_argument("--show-guides", action="store_true", help="Draw construction guides")
    return parser.parse_args()


def deep_merge(base: dict[str, Any], override: dict[str, Any]) -> dict[str, Any]:
    merged = copy.deepcopy(base)
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(merged.get(key), dict):
            merged[key] = deep_merge(merged[key], value)
        else:
            merged[key] = value
    return merged


def load_config(path: Path | None) -> dict[str, Any]:
    config = copy.deepcopy(DEFAULT_CONFIG)
    if path is None:
        return config

    with path.open("r", encoding="utf-8") as config_file:
        loaded = json.load(config_file)
    if not isinstance(loaded, dict):
        raise ValueError("Config root must be a JSON object")
    return deep_merge(config, loaded)


def apply_cli_overrides(config: dict[str, Any], args: argparse.Namespace) -> None:
    page = config["page"]
    scale = config["scale"]

    simple_overrides = {
        "width_mm": (page, args.width_mm),
        "height_mm": (page, args.height_mm),
        "center_x_mm": (scale, args.center_x_mm),
        "center_y_mm": (scale, args.center_y_mm),
        "radius_mm": (scale, args.radius_mm),
        "start_angle_deg": (scale, args.start_angle_deg),
        "end_angle_deg": (scale, args.end_angle_deg),
        "min_value": (scale, args.min_value),
        "max_value": (scale, args.max_value),
        "minor_step": (scale, args.minor_step),
        "medium_step": (scale, args.medium_step),
        "major_step": (scale, args.major_step),
    }
    for key, (target, value) in simple_overrides.items():
        if value is not None:
            target[key] = value

    if args.label_values:
        config["labels"]["values"] = [
            float(part.strip()) for part in args.label_values.split(",") if part.strip()
        ]
    if args.unit is not None:
        config["unit"]["text"] = args.unit
    if args.font_family is not None:
        config.setdefault("font", {})["family"] = args.font_family
    if args.show_guides:
        config["guides"]["show_pivot"] = True
        config["guides"]["show_arc_circle"] = True
        config["guides"]["show_start_end"] = True


def fmt(number: float) -> str:
    text = f"{number:.4f}".rstrip("0").rstrip(".")
    return text or "0"


def attrs(**items: Any) -> str:
    parts: list[str] = []
    for key, value in items.items():
        if value is None:
            continue
        svg_key = key.rstrip("_").replace("_", "-")
        if isinstance(value, float):
            value = fmt(value)
        parts.append(f"{svg_key}={quoteattr(str(value))}")
    return " ".join(parts)


def value_key(value: float) -> str:
    if abs(value - round(value)) < 1e-9:
        return str(int(round(value)))
    return fmt(value)


def point_on_circle(cx: float, cy: float, radius: float, angle_deg: float) -> tuple[float, float]:
    angle_rad = math.radians(angle_deg)
    return cx + radius * math.cos(angle_rad), cy - radius * math.sin(angle_rad)


def angle_for_point(cx: float, cy: float, point: list[float] | tuple[float, float]) -> float:
    x, y = point
    return math.degrees(math.atan2(cy - y, x - cx))


def circle_from_points(points: list[list[float]]) -> tuple[float, float, float]:
    (x1, y1), (x2, y2), (x3, y3) = points
    determinant = 2.0 * (
        x1 * (y2 - y3)
        + x2 * (y3 - y1)
        + x3 * (y1 - y2)
    )
    if abs(determinant) < 1e-9:
        raise ValueError("arc_points_mm must not be collinear")

    p1 = x1 * x1 + y1 * y1
    p2 = x2 * x2 + y2 * y2
    p3 = x3 * x3 + y3 * y3
    cx = (p1 * (y2 - y3) + p2 * (y3 - y1) + p3 * (y1 - y2)) / determinant
    cy = (p1 * (x3 - x2) + p2 * (x1 - x3) + p3 * (x2 - x1)) / determinant
    radius = math.hypot(x1 - cx, y1 - cy)
    return cx, cy, radius


def apply_measured_geometry(config: dict[str, Any]) -> None:
    scale = config["scale"]
    arc_points = scale.get("arc_points_mm") or []
    if arc_points:
        if len(arc_points) != 3:
            raise ValueError("scale.arc_points_mm must contain exactly three [x, y] points")
        cx, cy, radius = circle_from_points(arc_points)
        scale["center_x_mm"] = cx
        scale["center_y_mm"] = cy
        scale["radius_mm"] = radius
        scale.setdefault("start_point_mm", arc_points[0])
        scale.setdefault("end_point_mm", arc_points[2])
        if scale.get("start_point_mm") is None:
            scale["start_point_mm"] = arc_points[0]
        if scale.get("end_point_mm") is None:
            scale["end_point_mm"] = arc_points[2]

    cx = float(scale["center_x_mm"])
    cy = float(scale["center_y_mm"])
    if scale.get("start_point_mm") is not None:
        scale["start_angle_deg"] = angle_for_point(cx, cy, scale["start_point_mm"])
    if scale.get("end_point_mm") is not None:
        scale["end_angle_deg"] = angle_for_point(cx, cy, scale["end_point_mm"])


def stepped_values(start: float, stop: float, step: float) -> list[float]:
    if step <= 0:
        raise ValueError("Tick steps must be positive")
    count = int(math.floor((stop - start) / step + 1e-9))
    values = [start + index * step for index in range(count + 1)]
    if not values or abs(values[-1] - stop) > 1e-7:
        values.append(stop)
    return values


def is_multiple(value: float, origin: float, step: float | None) -> bool:
    if step is None or step <= 0:
        return False
    ratio = (value - origin) / step
    return abs(ratio - round(ratio)) < 1e-7


def value_to_angle(config: dict[str, Any], value: float) -> float:
    scale = config["scale"]
    min_value = float(scale["min_value"])
    max_value = float(scale["max_value"])
    if abs(max_value - min_value) < 1e-9:
        raise ValueError("min_value and max_value must be different")
    phase = (value - min_value) / (max_value - min_value)
    return float(scale["start_angle_deg"]) + phase * (
        float(scale["end_angle_deg"]) - float(scale["start_angle_deg"])
    )


def config_lookup(table: dict[str, Any], value: float, default: float = 0.0) -> float:
    for key in (value_key(value), fmt(value), str(value)):
        if key in table:
            return float(table[key])
    return default


def label_for_value(labels: dict[str, Any], value: float) -> str:
    return str(labels.get("format", "{:g}").format(value))


def svg_text(
    x: float,
    y: float,
    text: str,
    *,
    font_family: str,
    font_size: float,
    fill: str,
    font_weight: str = "400",
    anchor: str = "middle",
    rotate_deg: float | None = None,
) -> str:
    transform = None
    if rotate_deg is not None and abs(rotate_deg) > 1e-9:
        transform = f"rotate({fmt(rotate_deg)} {fmt(x)} {fmt(y)})"
    font_size_value = f"{fmt(font_size)}mm"
    text_attrs = attrs(
        x=x,
        y=y,
        fill=fill,
        font_family=font_family,
        font_size=font_size_value,
        font_weight=font_weight,
        text_anchor=anchor,
        dominant_baseline="middle",
        transform=transform,
    )
    return (
        f"  <text {text_attrs}>{escape(text)}</text>"
    )


def render_svg(config: dict[str, Any]) -> str:
    apply_measured_geometry(config)

    page = config["page"]
    face = config["face"]
    scale = config["scale"]
    labels = config["labels"]
    unit = config["unit"]
    guides = config["guides"]

    width = float(page["width_mm"])
    height = float(page["height_mm"])
    ink = config["ink"]
    default_font_family = str(
        config.get("font", {}).get("family") or "Helvetica, Arial, sans-serif"
    )
    tick_color = scale.get("tick_color") or ink
    label_color = labels.get("color") or ink
    unit_color = unit.get("color") or ink
    label_font_family = str(labels.get("font_family") or default_font_family)
    unit_font_family = str(unit.get("font_family") or default_font_family)
    cx = float(scale["center_x_mm"])
    cy = float(scale["center_y_mm"])
    radius = float(scale["radius_mm"])
    svg_attrs = attrs(
        width=f"{fmt(width)}mm",
        height=f"{fmt(height)}mm",
        viewBox=f"0 0 {fmt(width)} {fmt(height)}",
    )

    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        f'<svg xmlns="http://www.w3.org/2000/svg" {svg_attrs}>',
        "  <title>Parametric panel meter scale</title>",
        "  <desc>Generated by tools/panel_meter_scale_svg.py; dimensions are in millimetres.</desc>",
    ]

    corner_radius = float(face.get("corner_radius_mm", 0))
    if face.get("draw_background", True):
        background_attrs = attrs(
            x=0,
            y=0,
            width=width,
            height=height,
            rx=corner_radius,
            ry=corner_radius,
            fill=page.get("background", "#ffffff"),
        )
        lines.append(f"  <rect {background_attrs} />")
    if face.get("draw_border", False):
        border_width = float(face.get("border_width_mm", 0.15))
        border_inset = border_width / 2.0
        border_attrs = attrs(
            x=border_inset,
            y=border_inset,
            width=max(0.0, width - border_width),
            height=max(0.0, height - border_width),
            rx=corner_radius,
            ry=corner_radius,
            fill="none",
            stroke=face.get("border_color", "#000000"),
            stroke_width=border_width,
        )
        lines.append(f"  <rect {border_attrs} />")

    lines.append('  <g id="scale-ticks" fill="none">')
    min_value = float(scale["min_value"])
    max_value = float(scale["max_value"])
    for value in stepped_values(min_value, max_value, float(scale["minor_step"])):
        if is_multiple(value, min_value, float(scale.get("major_step") or 0)) or value in (min_value, max_value):
            tick_length = float(scale["major_tick_length_mm"])
            tick_width = float(scale["major_tick_width_mm"])
        elif is_multiple(value, min_value, float(scale.get("medium_step") or 0)):
            tick_length = float(scale["medium_tick_length_mm"])
            tick_width = float(scale["medium_tick_width_mm"])
        else:
            tick_length = float(scale["minor_tick_length_mm"])
            tick_width = float(scale["minor_tick_width_mm"])

        angle = value_to_angle(config, value)
        x1, y1 = point_on_circle(cx, cy, radius, angle)
        x2, y2 = point_on_circle(cx, cy, radius - tick_length, angle)
        tick_attrs = attrs(
            x1=x1,
            y1=y1,
            x2=x2,
            y2=y2,
            stroke=tick_color,
            stroke_width=tick_width,
            stroke_linecap=scale.get("tick_linecap", "butt"),
        )
        lines.append(f"    <line {tick_attrs} />")
    lines.append("  </g>")

    label_values = labels.get("values")
    if label_values is None:
        label_values = stepped_values(min_value, max_value, float(scale["major_step"]))
    lines.append('  <g id="scale-labels">')
    for raw_value in label_values:
        value = float(raw_value)
        angle = value_to_angle(config, value) + config_lookup(labels.get("angle_offsets_deg", {}), value)
        label_radius = float(labels["radius_mm"]) + config_lookup(labels.get("radial_offsets_mm", {}), value)
        x, y = point_on_circle(cx, cy, label_radius, angle)
        x += config_lookup(labels.get("x_offsets_mm", {}), value)
        y += config_lookup(labels.get("y_offsets_mm", {}), value)
        lines.append(
            svg_text(
                x,
                y,
                label_for_value(labels, value),
                font_family=label_font_family,
                font_size=float(labels["font_size_mm"]),
                font_weight=str(labels.get("font_weight", "400")),
                fill=label_color,
            )
        )
    lines.append("  </g>")

    if unit.get("text"):
        lines.append('  <g id="unit-label">')
        lines.append(
            svg_text(
                float(unit["x_mm"]),
                float(unit["y_mm"]),
                str(unit["text"]),
                font_family=unit_font_family,
                font_size=float(unit["font_size_mm"]),
                font_weight=str(unit.get("font_weight", "400")),
                fill=unit_color,
            )
        )
        lines.append("  </g>")

    if config.get("extra_text"):
        lines.append('  <g id="extra-text">')
        for item in config["extra_text"]:
            lines.append(
                svg_text(
                    float(item["x_mm"]),
                    float(item["y_mm"]),
                    str(item["text"]),
                    font_family=item.get("font_family") or label_font_family,
                    font_size=float(item.get("font_size_mm", labels["font_size_mm"])),
                    font_weight=str(item.get("font_weight", "400")),
                    fill=item.get("color") or ink,
                    anchor=item.get("anchor", "middle"),
                    rotate_deg=item.get("rotate_deg"),
                )
            )
        lines.append("  </g>")

    if config.get("holes"):
        lines.append('  <g id="holes" fill="none">')
        for hole in config["holes"]:
            diameter = float(hole["diameter_mm"])
            hole_attrs = attrs(
                cx=float(hole["x_mm"]),
                cy=float(hole["y_mm"]),
                r=diameter / 2.0,
                stroke=hole.get("color", "#d32f2f"),
                stroke_width=float(hole.get("stroke_width_mm", 0.15)),
                stroke_dasharray=hole.get("dasharray"),
            )
            lines.append(f"    <circle {hole_attrs} />")
        lines.append("  </g>")

    if guides.get("show_pivot") or guides.get("show_arc_circle") or guides.get("show_start_end"):
        guide_color = guides.get("color", "#0b72b9")
        lines.append('  <g id="construction-guides" fill="none" opacity="0.65">')
        if guides.get("show_arc_circle"):
            arc_guide_attrs = attrs(
                cx=cx,
                cy=cy,
                r=radius,
                stroke=guide_color,
                stroke_width=0.12,
                stroke_dasharray="1.5 1.5",
            )
            lines.append(f"    <circle {arc_guide_attrs} />")
        if guides.get("show_pivot"):
            pivot_attrs = attrs(
                cx=cx,
                cy=cy,
                r=1.0,
                stroke=guide_color,
                stroke_width=0.2,
            )
            lines.append(f"    <circle {pivot_attrs} />")
            pivot_h_attrs = attrs(
                x1=cx - 3.0,
                y1=cy,
                x2=cx + 3.0,
                y2=cy,
                stroke=guide_color,
                stroke_width=0.15,
            )
            lines.append(f"    <line {pivot_h_attrs} />")
            pivot_v_attrs = attrs(
                x1=cx,
                y1=cy - 3.0,
                x2=cx,
                y2=cy + 3.0,
                stroke=guide_color,
                stroke_width=0.15,
            )
            lines.append(f"    <line {pivot_v_attrs} />")
        if guides.get("show_start_end"):
            for guide_value in (min_value, max_value):
                angle = value_to_angle(config, guide_value)
                x1, y1 = point_on_circle(cx, cy, radius - 10.0, angle)
                x2, y2 = point_on_circle(cx, cy, radius + 10.0, angle)
                endpoint_attrs = attrs(
                    x1=x1,
                    y1=y1,
                    x2=x2,
                    y2=y2,
                    stroke=guide_color,
                    stroke_width=0.15,
                    stroke_dasharray="1 1",
                )
                lines.append(f"    <line {endpoint_attrs} />")
        lines.append("  </g>")

    lines.append("</svg>")
    return "\n".join(lines) + "\n"


def main() -> int:
    args = parse_args()
    try:
        config = load_config(args.config)
        apply_cli_overrides(config, args)
        svg = render_svg(config)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"panel_meter_scale_svg.py: {error}", file=sys.stderr)
        return 1

    if args.out:
        args.out.write_text(svg, encoding="utf-8")
    else:
        sys.stdout.write(svg)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
