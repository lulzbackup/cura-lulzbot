$fn = 50;

module wiper(
	x = 10,
	y = 10,
	z = 3
) {
	translate([x, y, z]){
		import("wiper_mount_v1.1.stl");

		//wiper pad itself
		translate([5, 5, 0]){
			cube(size = [90, 6.5, 12.5], center = false);
		}
	}
}

module auto_leveling_bed_corner(
	x = 0,
	y = 0,
	z = 11,
	inner_radius = 1.7,
	outer_radius = 11,
	washer_thickness = 1.5,
	angle = 0
) {
	z_translation = 3.25;
	translate([x, y, 0]) {
		rotate(angle, v=[]) {
	
			//Washer
			translate([outer_radius, outer_radius, z]) {
				cylinder(
					h = washer_thickness,
					r1 = outer_radius,
					r2 = outer_radius,
					center = false);
			}
		
			//Pillar
			translate([outer_radius, outer_radius, 0]) {
				cylinder(
					h = z,
					r1 = inner_radius,
					r2 = inner_radius,
					center = false);
			}
			
			//Flexible bed corners
			translate([0, 0, z_translation]) {
				import("bed_corner_v2.7.stl", center = false);
			}
		}
	}
}

module print_surface(
	x = 10,
	y = 10,
	plate_thickness = 2,
	x_mov = 0,
	y_mov = 0,
	z_mov = 0
) {
	translate([x_mov, y_mov, z_mov]) {
		cube(size = [x, y, plate_thickness], center = false);
	}
}

module all_bed_corners(
	x = 50,
	y = 50,
	offset = 0
) {
	auto_leveling_bed_corner(0, 0, angle = 0);
	auto_leveling_bed_corner(x+offset, 0, angle = 90);
	auto_leveling_bed_corner(x+offset, y+offset, angle = 180);
	auto_leveling_bed_corner(0, y+offset, angle = 270);
}

separation = 30;
all_bed_corners();
print_surface(x_mov = -separation );
wiper(100, separation );