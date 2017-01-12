use <lulzbot_generic_components.scad>;

x = 150;
y = 150;
plate_thickness = 11;

module bed_plate() {
	translate([0, 0, 0]){
		import("mini_bed_mount_plate_revC_simplified.stl");
	}
}

all_bed_corners(x = x, y = y, offset = 50);
wiper(x = 50, y = 187, z = 3);
bed_plate();
print_surface(
	x = 170,
	y = 170,
	plate_thickness = 4,
	x_mov = 15,
	y_mov = 15,
	z_mov = 7
);