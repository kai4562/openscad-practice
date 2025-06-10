// === Configuration Parameters ===
layer_accuracy = 0.25; // detalization in mm (0.25,0.4,0.5,1.0,2,3,4,5,6,10,20)
is_vase = 0; // 1 for vase, 0 for candybowl

wave_count = 7; // quantity of protrusion
twist_angle = 40; // angle of twist
vertical_wave_portion = 0.82; // part of sinusoid vertical 0.3-1.0
twist_wave_portion = 3; // part of sinusoid for twist or 0 for linear
vertical_coefficient = 0.1; // koeff vertical < 1.0
protrusion_coefficient = 0.06; // koeff protrusion < 0.5

// === Calculated Parameters ===
total_vertical_wave = ((is_vase == 1) ? 1 : 0) + vertical_wave_portion; // part of sinusoid vertical 0.5-1.0 for bowl, 1.5-1.9 for vase
object_height = (is_vase == 1) ? 180 : 60; // height of vase
base_diameter = 100; // base diameter

// === Mathematical Functions ===
// Calculate radius variation based on height (vertical wave)
function radius_by_height(z) = base_diameter / 2 + sin(total_vertical_wave * 180 * z / object_height) * vertical_coefficient * base_diameter / 2;

// Calculate radius variation based on angle (horizontal wave/protrusion)
function radius_by_angle(angle) = sin(angle * wave_count) * protrusion_coefficient * base_diameter / 2;

// Calculate twist angle based on height
function twist_by_height(z) = ((twist_wave_portion == 0) ? 1 : sin(twist_wave_portion * 180 * z / object_height)) * twist_angle * z / object_height;

// Main function: combine all radius variations
function calculate_radius(z, angle) = radius_by_height(z) + radius_by_angle(angle + twist_by_height(z));

// === Mesh Resolution Calculations ===
layer_height = object_height / floor(object_height / layer_accuracy);
vertical_step = layer_height; // height of layer
segments_per_circle = 360 / layer_height; // quantity of segments
angle_step = 360 / segments_per_circle; // step: angle of segment

module shape() {
    // === Generate Points ===
    // Create all vertices for the mesh
    mesh_points = [for (z = [0:vertical_step:object_height], angle = [0:angle_step:360 - angle_step]) 
        [sin(angle) * calculate_radius(z, angle), 
         cos(angle) * calculate_radius(z, angle), 
         z]];

    // === Calculate Mesh Statistics ===
    total_faces = segments_per_circle * object_height / vertical_step;
    echo("accuracy", layer_height, "faces", 2 * total_faces + 2);
    
    // === Generate Side Faces ===
    // Create triangular faces for the curved surface
    side_faces = [for (layer = [0:segments_per_circle:total_faces - segments_per_circle], 
                      segment = [0:segments_per_circle - 1], 
                      triangle = [0:1])
        (triangle == 0) ? 
            ((segment == segments_per_circle - 1) ? 
                [layer + segments_per_circle - 1, layer, layer + segments_per_circle] : 
                [layer + segment, layer + segment + 1, layer + segment + segments_per_circle + 1]) :
            ((segment == segments_per_circle - 1) ? 
                [layer + segments_per_circle - 1, layer + segments_per_circle, layer + 2 * segments_per_circle - 1] : 
                [layer + segment, layer + segment + segments_per_circle + 1, layer + segment + segments_per_circle])];

    // === Combine All Faces ===
    // Add bottom face, top face, and all side faces
    all_faces = concat(
        [[for (i = [0:segments_per_circle - 1]) i]], // bottom face
        [[for (i = [total_faces:total_faces + segments_per_circle - 1]) i]], // top face
        side_faces // side faces
    );

    // === Create 3D Object ===
    polyhedron(points = mesh_points, faces = all_faces);
}

// === Main Output ===
translate([0, 0, -object_height / 2])
shape();
