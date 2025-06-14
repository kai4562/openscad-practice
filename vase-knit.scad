// === Configuration Parameters ===
diameter = 100; // base diameter of the circle in mm
height = 0.42; // height of each layer in mm
line_thickness = 1; // thickness of the line in mm
num_teeth = 50; // number of gear teeth
tooth_extension = 1; // how much gear teeth extend outward in mm
valley_depth = 1; // how much valleys indent inward in mm
tooth_width_ratio = 0.4; // ratio of tooth width to gap width (0.5 = equal)
corner_radius = 0.3; // radius for rounding corners in mm
layer_spacing = height; // vertical spacing between layers in mm (no gap)
rotation_offset = 360 / (num_teeth * 4); // rotation so top peaks align with bottom valleys
num_layers = 200; // number of layers to stack

// === Vase Shape Parameters ===
enable_vase_shape = 1; // 1 = enable vase shaping, 0 = cylinder
vase_amplitude = 20; // amplitude of diameter variation in mm
vase_frequency = 2; // frequency of sine waves (number of complete cycles)
vase_phase = 600; // phase shift in degrees
vase_taper = 0.5; // tapering factor (0 = no taper, 1 = full taper to point)

// === Diameter Calculation Function ===
function calculate_diameter(layer) = 
    let(
        height_ratio = layer / (num_layers - 1), // 0 to 1
        sine_variation = sin(vase_frequency * 360 * height_ratio + vase_phase) * vase_amplitude,
        taper_factor = 1 - (vase_taper * height_ratio),
        final_diameter = enable_vase_shape ? 
            (diameter + sine_variation) * taper_factor : 
            diameter
    )
    max(final_diameter, line_thickness * 3); // minimum diameter to avoid invalid shapes

// === Basic Circle Module ===
module basic_circle(current_diameter) {
    linear_extrude(height = height) {
        difference() {
            // Outer gear polygon with linear teeth
            offset(r = corner_radius, $fn = 8)
            offset(r = -corner_radius)
            polygon([for (i = [0:num_teeth-1]) each
                let(
                    base_angle = i * 360 / num_teeth,
                    tooth_angle = 360 / num_teeth * tooth_width_ratio,
                    gap_angle = 360 / num_teeth * (1 - tooth_width_ratio),
                    // 4 points per tooth: valley_left, tooth_left, tooth_right, valley_right
                    valley_radius = (current_diameter/2) - valley_depth,
                    tooth_radius = (current_diameter/2) + tooth_extension
                ) [
                    // Valley left
                    [valley_radius * cos(base_angle), valley_radius * sin(base_angle)],
                    // Tooth left
                    [tooth_radius * cos(base_angle + gap_angle/2), tooth_radius * sin(base_angle + gap_angle/2)],
                    // Tooth right  
                    [tooth_radius * cos(base_angle + gap_angle/2 + tooth_angle), tooth_radius * sin(base_angle + gap_angle/2 + tooth_angle)],
                    // Valley right
                    [valley_radius * cos(base_angle + gap_angle/2 + tooth_angle + gap_angle/2), valley_radius * sin(base_angle + gap_angle/2 + tooth_angle + gap_angle/2)]
                ]
            ]);
            
            // Inner gear polygon with same pattern
            offset(r = corner_radius, $fn = 8)
            offset(r = -corner_radius)
            polygon([for (i = [0:num_teeth-1]) each
                let(
                    base_angle = i * 360 / num_teeth,
                    tooth_angle = 360 / num_teeth * tooth_width_ratio,
                    gap_angle = 360 / num_teeth * (1 - tooth_width_ratio),
                    inner_base_radius = (current_diameter/2) - line_thickness,
                    valley_radius = inner_base_radius - valley_depth,
                    tooth_radius = inner_base_radius + tooth_extension
                ) [
                    // Valley left
                    [valley_radius * cos(base_angle), valley_radius * sin(base_angle)],
                    // Tooth left
                    [tooth_radius * cos(base_angle + gap_angle/2), tooth_radius * sin(base_angle + gap_angle/2)],
                    // Tooth right  
                    [tooth_radius * cos(base_angle + gap_angle/2 + tooth_angle), tooth_radius * sin(base_angle + gap_angle/2 + tooth_angle)],
                    // Valley right
                    [valley_radius * cos(base_angle + gap_angle/2 + tooth_angle + gap_angle/2), valley_radius * sin(base_angle + gap_angle/2 + tooth_angle + gap_angle/2)]
                ]
            ]);
        }
    }
}

// === Main Output ===
for (layer = [0:num_layers-1]) {
    translate([0, 0, layer * layer_spacing]) {
        rotate([0, 0, (layer % 2) * rotation_offset]) {
            basic_circle(calculate_diameter(layer));
        }
    }
}
