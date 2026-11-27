-- Sci-fi continuous laser cannon. Uses ACE's normal gun, ammo, heat and point systems.
ACE.DefineGunClass("SL", {
	type = "Gun",
	name = "Sci-Fi Laser",
	desc = "Continuous-beam laser weapons. Sustained fire ramps beam power and generates severe heat.",
	muzzleflash = "SL",
	rofmod = 0.08,
	maxrof = 600,
	sound = "",
	noloader = true,
})

ACE.DefineGun("50mmSL", {
	name = "50mm Continuous Laser",
	desc = "A bright yellow continuous laser. Beam power ramps up while firing; ACE handles overheating damage without disabling the weapon.",
	model = "models/weapons/w_irifle.mdl",
	gunclass = "SL",
	caliber = 5.0,
	weight = 650,
	year = 2022,
	nomag = true,
	maxrof = 600,
	rofmod = 0.08,
	round = {
		maxlength = 24,
		propweight = 0.2,
	},
})

ACE.DefineMuzzleFlash("SL", {
	muzzlefunc = function() end,
})
