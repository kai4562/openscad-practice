// === Configuration Parameters ===
diameter = 100; // diameter of the circle in mm
height = 0.42; // height of the circle in mm
line_thickness = 1; // thickness of the line in mm
corners = 100; // number of corners/sides for the polygon
jagged_extension = 4; // how much jagged points extend outward in mm
corner_radius = 1; // radius for rounding corners in mm
layer_spacing = height; // vertical spacing between layers in mm (no gap)
rotation_offset = 360 / corners; // rotation so top peaks align with bottom valleys
num_layers = 20; // number of layers to stack

// === Basic Circle Module ===
module basic_circle() {
    linear_extrude(height = height) {
        difference() {
            // Outer jagged polygon with rounded corners
            offset(r = corner_radius, $fn = 16)
            offset(r = -corner_radius)
            polygon([for (i = [0:corners-1]) 
                let(
                    angle = i * 360 / corners,
                    // Alternate between normal radius and extended radius
                    radius = (diameter/2) + (i % 2 == 0 ? jagged_extension : 0)
                )
                [radius * cos(angle), radius * sin(angle)]
            ]);
            
            // Inner jagged polygon with rounded corners
            offset(r = corner_radius, $fn = 16)
            offset(r = -corner_radius)
            polygon([for (i = [0:corners-1]) 
                let(
                    angle = i * 360 / corners,
                    // Inner radius with same jagged pattern
                    inner_base_radius = (diameter/2) - line_thickness,
                    radius = inner_base_radius + (i % 2 == 0 ? jagged_extension : 0)
                )
                [radius * cos(angle), radius * sin(angle)]
            ]);
        }
    }
}

// === Main Output ===
for (layer = [0:num_layers-1]) {
    translate([0, 0, layer * layer_spacing]) {
        rotate([0, 0, (layer % 2) * rotation_offset]) {
            basic_circle();
        }
    }
}
