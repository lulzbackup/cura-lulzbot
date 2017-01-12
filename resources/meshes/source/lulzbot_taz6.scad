use <lulzbot_generic_components.scad>;

x = 280;
y = 280;
plate_thickness = 4;
print_surface(
	x = x,
	y = y,
	plate_thickness = 4,
	z_mov = 7
);

radius = 11;
offset = 22;
translate([-radius, -radius]) {
	all_bed_corners(x = x, y = y, offset = offset);
}

//Wiper
rotate(a = [0, 0, 90]) {
	wiper(x = offset, y = 0, z = 3);
}

//Slap in simplified model of bed plate here