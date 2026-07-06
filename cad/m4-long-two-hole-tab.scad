/*
    Parametric M4 long two-hole tab
    -----------------------------------------
    Pill-shaped tab with two loose M4 clearance holes.

    Copy the alignment values from cad/box-generator.scad so the holes
    line up with the two holes placed to the left and right of the cutout.

    Orientation:
      XY = tab outline
      Z  = tab thickness
      Z = 0 is the print-bed face
*/


/* [Box alignment] */

// Copy from box-generator.scad
front_cutout_width = 60;

// Copy from box-generator.scad
cutout_side_hole_center_offset = 5;

// Copy from box-generator.scad
cutout_side_hole_diameter = 4.8;

// Center-to-center spacing between the two box cutout side holes
hole_spacing = front_cutout_width + 2 * cutout_side_hole_center_offset;


/* [Tab size] */

tab_height = 12;

// Default keeps each hole centered in one rounded end.
tab_width = hole_spacing + tab_height;

tab_thickness = 2;


/* [Rendering] */

$fn = 64;
epsilon = 0.1;


tab_end_radius = tab_height / 2;
hole_left_x = (tab_width - hole_spacing) / 2;
hole_right_x = (tab_width + hole_spacing) / 2;
hole_y = tab_height / 2;


module rounded_tab_outline() {
    hull() {
        translate([
            tab_end_radius,
            tab_end_radius
        ])
        circle(r = tab_end_radius);

        translate([
            tab_width - tab_end_radius,
            tab_end_radius
        ])
        circle(r = tab_end_radius);
    }
}


module screw_clearance_hole(x) {
    translate([
        x,
        hole_y,
        -epsilon
    ])
    cylinder(
        d = cutout_side_hole_diameter,
        h = tab_thickness + 2 * epsilon
    );
}


module long_two_hole_tab() {
    difference() {
        linear_extrude(height = tab_thickness)
        rounded_tab_outline();

        screw_clearance_hole(hole_left_x);
        screw_clearance_hole(hole_right_x);
    }
}


assert(front_cutout_width > 0, "front_cutout_width must be positive");
assert(
    cutout_side_hole_center_offset > 0,
    "cutout_side_hole_center_offset must be positive"
);
assert(
    cutout_side_hole_diameter > 0,
    "cutout_side_hole_diameter must be positive"
);
assert(tab_width > 0, "tab_width must be positive");
assert(tab_height > 0, "tab_height must be positive");
assert(tab_thickness > 0, "tab_thickness must be positive");
assert(
    tab_width >= tab_height,
    "tab_width must be at least tab_height for fully rounded ends"
);
assert(
    cutout_side_hole_diameter < tab_height,
    "cutout_side_hole_diameter must be smaller than tab_height"
);
assert(
    hole_spacing > cutout_side_hole_diameter,
    "hole_spacing must be larger than the hole diameter"
);
assert(
    hole_left_x >= cutout_side_hole_diameter / 2,
    "Left hole would break through the left end"
);
assert(
    hole_right_x <= tab_width - cutout_side_hole_diameter / 2,
    "Right hole would break through the right end"
);

long_two_hole_tab();
