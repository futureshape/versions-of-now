/*
    Parametric IKEA SKÅDIS box
    -----------------------------------------
    - Attaches using M4 screws inserted through
      the SKÅDIS board from behind.
    - Uses only the mutually aligned SKÅDIS holes.
    - Open at the rear, closed on all other sides.
    - Designed to print with the front face on the bed.

    Orientation:
      Z = box depth
      Z = 0 is the front face / print-bed face
      Z = box_depth is the open rear facing the pegboard
*/


/* [Box size] */

// Number of aligned SKÅDIS holes horizontally
holes_x = 4;

// Number of aligned SKÅDIS holes vertically
holes_y = 2;

// Distance from front face to pegboard
box_depth = 45;


/* [Wall dimensions] */

wall_thickness  = 2;
front_thickness = 1;


/* [Front cutout] */

// Cut a centered rectangle into the print-bed face at Z = 0
front_cutout_enabled = true;

// Size of the centered cutout on the front face
front_cutout_width = 60;
front_cutout_height = 30;

// Depth of the cut from the print-bed face. Use front_thickness
// for a through-hole in the front face.
front_cutout_depth = front_thickness;

// Add two loose M4 clearance holes to the left and right of the cutout
cutout_side_holes_enabled = true;

// Distance from each cutout side edge to the adjacent hole center
cutout_side_hole_center_offset = 5;

// Loose M4 clearance hole; no threading expected here
cutout_side_hole_diameter = 4.8;


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
// Approximately 3.2–3.5 mm is suitable for an M4 screw
// cutting its own thread into many printed plastics.
// Tune for your printer, material and screw type.
screw_pilot_diameter = 3.4;

// Length of screw engagement inside the printed post
screw_engagement = 10;

// Small unthreaded lead-in at the rear
screw_leadin_diameter = 4.3;
screw_leadin_depth = 1.5;


/* [Rendering] */

// Print only the front plate with through screw holes for a quick
// pegboard alignment test.
test_alignment_mode = false;

$fn = 48;
epsilon = 0.1;


/*
    Derived box dimensions

    For three holes, for example:

       20 mm + 40 mm + 40 mm + 20 mm = 120 mm

    Therefore the convenient result is:
       width  = holes_x × 40 mm
       height = holes_y × 40 mm
*/

box_width  = holes_x * hole_pitch;
box_height = holes_y * hole_pitch;

front_cutout_left_x = (box_width - front_cutout_width) / 2;
front_cutout_right_x = (box_width + front_cutout_width) / 2;
front_cutout_center_y = box_height / 2;

cutout_side_hole_left_x =
    front_cutout_left_x - cutout_side_hole_center_offset;

cutout_side_hole_right_x =
    front_cutout_right_x + cutout_side_hole_center_offset;

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
            box_width  - 2 * wall_thickness,
            box_height - 2 * wall_thickness,
            box_depth  - front_thickness + epsilon
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


module mounting_alignment_hole(x, y) {
    translate([
        x,
        y,
        -epsilon
    ])
    cylinder(
        d = screw_leadin_diameter,
        h = front_thickness + 2 * epsilon
    );
}


module cutout_side_hole(x) {
    translate([
        x,
        front_cutout_center_y,
        -epsilon
    ])
    cylinder(
        d = cutout_side_hole_diameter,
        h = front_thickness + 2 * epsilon
    );
}


module cutout_side_holes() {
    if (cutout_side_holes_enabled) {
        cutout_side_hole(cutout_side_hole_left_x);
        cutout_side_hole(cutout_side_hole_right_x);
    }
}


module front_face_cutout() {
    if (front_cutout_enabled) {
        translate([
            front_cutout_left_x,
            (box_height - front_cutout_height) / 2,
            -epsilon
        ])
        cube([
            front_cutout_width,
            front_cutout_height,
            front_cutout_depth + 2 * epsilon
        ]);
    }
}


module all_mounting_bosses() {

    for (column = [0 : holes_x - 1]) {

        for (row = [0 : holes_y - 1]) {

            is_corner =

                (column == 0 || column == holes_x - 1) &&

                (row == 0 || row == holes_y - 1);

            if (is_corner) {

                x = mounting_x(column);

                y = mounting_y(row);

                mounting_boss(x, y);

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

                x = mounting_x(column);

                y = mounting_y(row);

                mounting_pilot_hole(x, y);

            }

        }

    }

}


module all_mounting_alignment_holes() {

    for (column = [0 : holes_x - 1]) {

        for (row = [0 : holes_y - 1]) {

            is_corner =

                (column == 0 || column == holes_x - 1) &&

                (row == 0 || row == holes_y - 1);

            if (is_corner) {

                x = mounting_x(column);

                y = mounting_y(row);

                mounting_alignment_hole(x, y);

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
        front_face_cutout();
        cutout_side_holes();
    }
}


module alignment_test_plate() {
    difference() {
        cube([
            box_width,
            box_height,
            front_thickness
        ]);

        all_mounting_alignment_holes();
        front_face_cutout();
        cutout_side_holes();
    }
}


assert(holes_x >= 1, "holes_x must be at least 1");
assert(holes_y >= 1, "holes_y must be at least 1");
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
assert(
    !front_cutout_enabled || front_cutout_width > 0,
    "front_cutout_width must be positive when the front cutout is enabled"
);
assert(
    !front_cutout_enabled || front_cutout_height > 0,
    "front_cutout_height must be positive when the front cutout is enabled"
);
assert(
    !front_cutout_enabled ||
        front_cutout_width <= box_width - 2 * wall_thickness,
    "front_cutout_width must fit between the side walls"
);
assert(
    !front_cutout_enabled ||
        front_cutout_height <= box_height - 2 * wall_thickness,
    "front_cutout_height must fit between the top and bottom walls"
);
assert(
    !front_cutout_enabled ||
        front_cutout_depth > 0 && front_cutout_depth <= box_depth,
    "front_cutout_depth must be greater than 0 and no deeper than box_depth"
);
assert(
    !cutout_side_holes_enabled || front_cutout_enabled,
    "cutout_side_holes_enabled requires front_cutout_enabled"
);
assert(
    !cutout_side_holes_enabled || cutout_side_hole_diameter > 0,
    "cutout_side_hole_diameter must be positive"
);
assert(
    !cutout_side_holes_enabled || cutout_side_hole_center_offset > 0,
    "cutout_side_hole_center_offset must be positive"
);
assert(
    !cutout_side_holes_enabled ||
        cutout_side_hole_center_offset >= cutout_side_hole_diameter / 2,
    "cutout side holes would overlap the front cutout"
);
assert(
    !cutout_side_holes_enabled ||
        cutout_side_hole_left_x - cutout_side_hole_diameter / 2 >=
            wall_thickness,
    "Left cutout side hole would cut into the side wall"
);
assert(
    !cutout_side_holes_enabled ||
        cutout_side_hole_right_x + cutout_side_hole_diameter / 2 <=
            box_width - wall_thickness,
    "Right cutout side hole would cut into the side wall"
);

if (test_alignment_mode) {
    alignment_test_plate();
} else {
    skadis_box();
}
