/*
    Parametric M4 rounded tab
    -----------------------------------------
    Small pill-shaped tab with a loose M4 clearance hole near one end.

    Orientation:
      XY = tab outline
      Z  = tab thickness
      Z = 0 is the print-bed face
*/


/* [Tab size] */

tab_width = 45;
tab_height = 12;
tab_thickness = 2;


/* [Screw hole] */

// Loose M4 clearance hole; no threading expected here.
screw_hole_diameter = 4.8;

// Distance from the right end of the tab to the screw-hole center.
// Use tab_height / 2 to center the hole in the rounded end.
screw_hole_center_from_right_edge = tab_height / 2;


/* [Rendering] */

$fn = 64;
epsilon = 0.1;


tab_end_radius = tab_height / 2;
screw_hole_x = tab_width - screw_hole_center_from_right_edge;
screw_hole_y = tab_height / 2;


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


module screw_clearance_hole() {
    translate([
        screw_hole_x,
        screw_hole_y,
        -epsilon
    ])
    cylinder(
        d = screw_hole_diameter,
        h = tab_thickness + 2 * epsilon
    );
}


module rounded_tab() {
    difference() {
        linear_extrude(height = tab_thickness)
        rounded_tab_outline();

        screw_clearance_hole();
    }
}


assert(tab_width > 0, "tab_width must be positive");
assert(tab_height > 0, "tab_height must be positive");
assert(tab_thickness > 0, "tab_thickness must be positive");
assert(
    tab_width >= tab_height,
    "tab_width must be at least tab_height for fully rounded ends"
);
assert(screw_hole_diameter > 0, "screw_hole_diameter must be positive");
assert(
    screw_hole_diameter < tab_height,
    "screw_hole_diameter must be smaller than tab_height"
);
assert(
    screw_hole_center_from_right_edge >= screw_hole_diameter / 2,
    "Screw hole would break through the right end"
);
assert(
    screw_hole_center_from_right_edge <= tab_width - screw_hole_diameter / 2,
    "Screw hole would break through the left end"
);

rounded_tab();
