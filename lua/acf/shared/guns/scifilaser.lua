-- Sci-fi continuous laser cannon. Uses ACE's normal gun, ammo, heat and point systems.
ACE.DefineGunClass("SFL", {
	type = "Gun",
	spread = 0,
	name = "Sci-Fi Laser",
	desc = "Continuous-beam laser weapons. Sustained fire ramps beam power and generates severe heat.",
	muzzleflash = "SFL",
	rofmod = 0.08,
	maxrof = 600,
	sound = "acf_extra/tankfx/energy/laser-automatic.wav",
	noloader = true,
})

ACE.DefineGun("50mmSL", {
	name = "50mm Continuous Laser",
	desc = "A continuous bright-yellow laser powered by linked ACE electric batteries. Beam power ramps with sustained fire; overheating damages the gun but does not shut it off.",
	model = "models/weapons/w_irifle.mdl",
	gunclass = "SFL",
	caliber = 5.0,
	weight = 250,
	year = 2022,
	nomag = true,
	maxrof = 600,
	rofmod = 0.08,
	round = {
		maxlength = 24,
		propweight = 0.2,
	},
})

-- Upper interpolation anchor gives the continuous caliber selector a 50-130 mm
-- range. ACE interpolates between this and the 50 mm preset for custom sizes.
-- Weights are intentionally much lower than a conventional 130 mm cannon: 250 kg
-- at 50 mm and 1,800 kg at 130 mm, linearly interpolated by ACE.
ACE.DefineGun("130mmSL", {
	name = "130mm Continuous Laser",
	desc = "The large-bore 130 mm continuous laser interpolation anchor.",
	model = "models/weapons/w_irifle.mdl",
	gunclass = "SFL",
	caliber = 13.0,
	weight = 1800,
	year = 2022,
	nomag = true,
	maxrof = 600,
	rofmod = 0.08,
	round = {
		maxlength = 62.4,
		propweight = 0.52,
	},
})

ACE.DefineMuzzleFlash("SFL", {
	muzzlefunc = function() end,
})
