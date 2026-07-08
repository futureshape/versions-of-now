/*
    One-off parametric IKEA SKADIS box with two front cutouts
    ---------------------------------------------------------
    - Attaches using M4 screws inserted through the SKADIS board from behind.
    - Open at the rear, closed on all other sides.
    - Designed to print with the front face on the bed.
    - Front face has two matching cutouts and no front screw holes.

    Orientation:
      Z = box depth
      Z = 0 is the front face / print-bed face
      Z = box_depth is the open rear facing the pegboard
*/


/* [Box size] */

// Number of aligned SKADIS holes horizontally
holes_x = 4;

// Number of aligned SKADIS holes vertically
holes_y = 2;

// Distance from front face to pegboard
box_depth = 45;


/* [Wall dimensions] */

wall_thickness = 2;
front_thickness = 1;


/* [Front cutouts] */

// Matching dimensions for both front cutouts
front_cutout_width = 78.8;
front_cutout_height = 23.81;

// Depth of the cut from the print-bed face. Use front_thickness
// for through-holes in the front face.
front_cutout_depth = front_thickness;

// Minimum gap between the two cutouts, and between the lower cutout
// and the bottom edge of the box.
cutout_spacing = 5;


/* [SKADIS grid] */

// Effective spacing when alternate offset holes are skipped
hole_pitch = 40;

// Vertical length of each SKADIS slot. Used to push the screw
// centers toward the outer ends of the top and bottom slots.
skadis_slot_height = 15;

// Clearance left between the screw lead-in and the end of the slot
slot_end_safety_margin = 1;

// Box extends halfway towards the next unused aligned hole
edge_margin = hole_pitch / 2;


/* [Mounting posts] */

// Outer diameter of mounting posts
boss_diameter = 11;

// Diameter of blind pilot hole for an M4 screw.
//
// Approximately 3.2-3.5 mm is suitable for an M4 screw
// cutting its own thread into many printed plastics.
screw_pilot_diameter = 3.4;

// Length of screw engagement inside the printed post
screw_engagement = 10;

// Small unthreaded lead-in at the rear
screw_leadin_diameter = 4.3;
screw_leadin_depth = 1.5;


/* [Rendering] */

$fn = 48;
epsilon = 0.1;


box_width = holes_x * hole_pitch;
box_height = holes_y * hole_pitch;

front_cutout_x = (box_width - front_cutout_width) / 2;

cutout_stack_height = 2 * front_cutout_height + cutout_spacing;
centered_bottom_cutout_y = (box_height - cutout_stack_height) / 2;

bottom_cutout_y = max(cutout_spacing, centered_bottom_cutout_y);
top_cutout_y = bottom_cutout_y + front_cutout_height + cutout_spacing;

screw_slot_y_offset = max(
    0,
    (skadis_slot_height - screw_leadin_diameter) / 2 -
        slot_end_safety_margin
);


function mounting_x(column) =
    edge_margin + column * hole_pitch;


function mounting_y(row) =
    holes_y == 1
        ? box_height / 2
        : edge_margin + row * hole_pitch +
            (row == 0 ? -screw_slot_y_offset : screw_slot_y_offset);


module outer_shell() {
    difference() {
        cube([
            box_width,
            box_height,
            box_depth
        ]);

        // Remove the interior. Extending beyond the rear leaves
        // the entire pegboard-facing side open.
        translate([
            wall_thickness,
            wall_thickness,
            front_thickness
        ])
        cube([
            box_width - 2 * wall_thickness,
            box_height - 2 * wall_thickness,
            box_depth - front_thickness + epsilon
        ]);
    }
}


module mounting_boss(x, y) {
    translate([x, y, front_thickness])
    cylinder(
        d = boss_diameter,
        h = box_depth - front_thickness
    );
}


module mounting_pilot_hole(x, y) {
    // Blind pilot hole entering from the open rear.
    translate([
        x,
        y,
        box_depth - screw_engagement
    ])
    cylinder(
        d = screw_pilot_diameter,
        h = screw_engagement + epsilon
    );

    // Slightly larger opening to help locate the screw.
    translate([
        x,
        y,
        box_depth - screw_leadin_depth
    ])
    cylinder(
        d1 = screw_pilot_diameter,
        d2 = screw_leadin_diameter,
        h = screw_leadin_depth + epsilon
    );
}


module front_cutout(y) {
    translate([
        front_cutout_x,
        y,
        -epsilon
    ])
    cube([
        front_cutout_width,
        front_cutout_height,
        front_cutout_depth + 2 * epsilon
    ]);
}


module front_cutouts() {
    front_cutout(bottom_cutout_y);
    front_cutout(top_cutout_y);
}


module all_mounting_bosses() {
    for (column = [0 : holes_x - 1]) {
        for (row = [0 : holes_y - 1]) {
            is_corner =
                (column == 0 || column == holes_x - 1) &&
                (row == 0 || row == holes_y - 1);

            if (is_corner) {
                mounting_boss(
                    mounting_x(column),
                    mounting_y(row)
                );
            }
        }
    }
}


module all_mounting_holes() {
    for (column = [0 : holes_x - 1]) {
        for (row = [0 : holes_y - 1]) {
            is_corner =
                (column == 0 || column == holes_x - 1) &&
                (row == 0 || row == holes_y - 1);

            if (is_corner) {
                mounting_pilot_hole(
                    mounting_x(column),
                    mounting_y(row)
                );
            }
        }
    }
}


module skadis_box() {
    difference() {
        union() {
            outer_shell();
            all_mounting_bosses();
        }

        all_mounting_holes();
        front_cutouts();
    }
}


assert(holes_x >= 1, "holes_x must be at least 1");
assert(holes_y >= 1, "holes_y must be at least 1");
assert(front_cutout_width > 0, "front_cutout_width must be positive");
assert(front_cutout_height > 0, "front_cutout_height must be positive");
assert(front_cutout_depth > 0, "front_cutout_depth must be positive");
assert(cutout_spacing >= 0, "cutout_spacing must not be negative");
assert(
    front_cutout_width <= box_width - 2 * wall_thickness,
    "front_cutout_width must fit between the side walls"
);
assert(
    box_height >= 2 * front_cutout_height + 2 * cutout_spacing,
    "box_height must fit two cutouts, the inter-cutout gap, and bottom spacing"
);
assert(
    top_cutout_y + front_cutout_height <= box_height,
    "Top cutout would extend beyond the top of the box"
);
assert(
    front_cutout_depth <= box_depth,
    "front_cutout_depth must be no deeper than box_depth"
);
assert(
    boss_diameter > screw_leadin_diameter + 2,
    "Mounting bosses are too narrow around the screw holes"
);
assert(
    box_depth > screw_engagement + front_thickness,
    "box_depth must exceed screw engagement plus front thickness"
);
assert(
    skadis_slot_height >= screw_leadin_diameter,
    "skadis_slot_height must be at least as large as screw_leadin_diameter"
);
assert(
    slot_end_safety_margin >= 0,
    "slot_end_safety_margin must not be negative"
);
assert(
    holes_y == 1 ||
        edge_margin - screw_slot_y_offset >= boss_diameter / 2,
    "Mounting bosses would extend beyond the top or bottom of the box"
);

skadis_box();
