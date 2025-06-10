// === Configuration Parameters ===
layer_accuracy = 0.25; // grid resolution in mm
is_vase = 0; // not used for flat surface

wave_count_x = 3; // quantity of waves in X direction
wave_count_y = 10; // quantity of waves in Y direction
wave_amplitude = 5; // height of waves in mm
phase_shift = 0; // phase shift between X and Y waves (0-360 degrees)
rotation_angle = 700; // rotation angle around Z-axis (yaw) in degrees
noise_amplitude = 0; // amplitude of noise in mm
noise_frequency = 5; // frequency of noise (higher = more detailed)
flat_bottom = 1; // 1 = flat bottom, 0 = current model
bottom_thickness = 10; // thickness of flat bottom in mm

// === Calculated Parameters ===
surface_width = 100; // width of the surface
surface_depth = 100; // depth of the surface
wave_height = wave_amplitude; // maximum height variation

// === Mathematical Functions ===
// Rotate coordinates around Z-axis
function rotate_coordinates(x, y, angle) = 
    let(
        rad = angle * PI / 180,
        cos_a = cos(rad),
        sin_a = sin(rad)
    )
    [x * cos_a - y * sin_a, x * sin_a + y * cos_a];

// Calculate height variation based on X position
function height_by_x(x) = sin(wave_count_x * 360 * x / surface_width) * wave_height / 2;

// Calculate height variation based on Y position  
function height_by_y(y) = sin(wave_count_y * 360 * y / surface_depth + phase_shift) * wave_height / 2;

// Generate pseudo-random noise based on coordinates
function noise(x, y) = 
    let(
        seed_x = floor(x * noise_frequency + surface_width/2),
        seed_y = floor(y * noise_frequency + surface_depth/2),
        // Simple hash function that works reliably in OpenSCAD
        hash = sin(seed_x * 12.9898 + seed_y * 78.233) * 43758.5453,
        normalized = (hash - floor(hash)) * 2 - 1
    )
    normalized * noise_amplitude;

// Main function: combine wave effects with rotation and noise
function calculate_height(x, y) = 
    let(
        // Convert to center-relative coordinates
        center_x = x - surface_width/2,
        center_y = y - surface_depth/2,
        // Rotate around center (negative angle to rotate pattern correctly)
        rotated_coords = rotate_coordinates(center_x, center_y, -rotation_angle),
        // Convert back to absolute coordinates
        rotated_x = rotated_coords[0] + surface_width/2,
        rotated_y = rotated_coords[1] + surface_depth/2,
        // Add noise to the original coordinates
        noise_value = noise(x, y)
    )
    height_by_x(rotated_x) + height_by_y(rotated_y) + noise_value;

// === Mesh Resolution Calculations ===
x_step = layer_accuracy;
y_step = layer_accuracy;
x_segments = floor(surface_width / x_step);
y_segments = floor(surface_depth / y_step);

module shape(rotate_z = 0) {
    // === Generate Points ===
    // Create all vertices for the flat wavy mesh
    top_points = [for (y_idx = [0:y_segments], x_idx = [0:x_segments]) 
        [x_idx * x_step - surface_width/2, 
         y_idx * y_step - surface_depth/2, 
         calculate_height(x_idx * x_step, y_idx * y_step)]];
    
    // Generate bottom points if flat_bottom is enabled
    bottom_points = flat_bottom ? 
        [for (y_idx = [0:y_segments], x_idx = [0:x_segments]) 
            [x_idx * x_step - surface_width/2, 
             y_idx * y_step - surface_depth/2, 
             -bottom_thickness]] : [];
    
    // Combine top and bottom points
    mesh_points = concat(top_points, bottom_points);

    // === Calculate Mesh Statistics ===
    total_points = flat_bottom ? (x_segments + 1) * (y_segments + 1) * 2 : (x_segments + 1) * (y_segments + 1);
    points_per_layer = (x_segments + 1) * (y_segments + 1);
    echo("grid size", x_segments + 1, "x", y_segments + 1, "points", total_points);
    
    // === Generate Faces ===
    // Create triangular faces for the top surface
    top_faces = [for (y = [0:y_segments - 1], x = [0:x_segments - 1], triangle = [0:1])
        let(
            bottom_left = y * (x_segments + 1) + x,
            bottom_right = bottom_left + 1,
            top_left = bottom_left + (x_segments + 1),
            top_right = top_left + 1
        )
        (triangle == 0) ? 
            [bottom_left, bottom_right, top_left] :
            [bottom_right, top_right, top_left]
    ];
    
    // Generate bottom faces if flat_bottom is enabled
    bottom_faces = flat_bottom ? 
        [for (y = [0:y_segments - 1], x = [0:x_segments - 1], triangle = [0:1])
            let(
                bottom_left = y * (x_segments + 1) + x + points_per_layer,
                bottom_right = bottom_left + 1,
                top_left = bottom_left + (x_segments + 1),
                top_right = top_left + 1
            )
            (triangle == 0) ? 
                [bottom_left, top_left, bottom_right] :
                [bottom_right, top_left, top_right]
        ] : [];
    
    // Generate side faces if flat_bottom is enabled
    side_faces = flat_bottom ? 
        concat(
            // Bottom edge (Y=0)
            [for (x = [0:x_segments - 1]) each [
                [x, x + points_per_layer, x + 1],
                [x + 1, x + points_per_layer, x + points_per_layer + 1]]],
            // Top edge (Y=max)
            [for (x = [0:x_segments - 1]) each
                let(base = y_segments * (x_segments + 1))
                [
                    [base + x + 1, base + x + points_per_layer, base + x],
                    [base + x + points_per_layer + 1, base + x + points_per_layer, base + x + 1]
                ]],
            // Left edge (X=0)
            [for (y = [0:y_segments - 1]) each
                let(base = y * (x_segments + 1))
                [
                    [base, base + points_per_layer + (x_segments + 1), base + points_per_layer],
                    [base + (x_segments + 1), base + points_per_layer + (x_segments + 1), base]
                ]],
            // Right edge (X=max)
            [for (y = [0:y_segments - 1]) each
                let(base = y * (x_segments + 1) + x_segments)
                [
                    [base + points_per_layer, base + points_per_layer + (x_segments + 1), base],
                    [base, base + points_per_layer + (x_segments + 1), base + (x_segments + 1)]
                ]]
        ) : [];
    
    // Combine all faces
    all_faces = concat(top_faces, bottom_faces, side_faces);

    // === Create 3D Object ===
    polyhedron(points = mesh_points, faces = all_faces);
}

// === Main Output ===
shape();
