-- Advanced material definitions for ACE's science-fiction armor set.
-- Density ratios are derived from documented bulk densities relative to RHA steel
-- (7,850 kg/m^3). Ballistic effectiveness and brittleness are game parameters:
-- there are no tank-scale ballistic test data for these hypothetical composites.

local function makeArmorResolution(Material, Entity, armor, losArmor, losArmorHealth, maxPenetration, FrArea, caliber, damageMult, Type)
	local HitRes = {}
	local effectiveness = Material.effectiveness
	local resiliance = Material.resiliance

	local HeatTypes = {
		HEAT = true,
		THEAT = true,
		HEATFS = true,
		THEATFS = true,
		CHEAT = true,
		GLATGM = true,
	}

	local OtherImpactTypes = {
		HE = true,
		HESH = true,
	}

	if HeatTypes[Type] then
		effectiveness = Material.HEATeffectiveness
		resiliance = Material.HEATresiliance
	elseif OtherImpactTypes[Type] then
		effectiveness = Material.HEeffectiveness
		resiliance = Material.HEresiliance
	end

	local curve = Material.curve
	local ductilityValue = (Entity.ACF.Ductility or 0) * 1.25
	local ductilityMult = 2 / (2 + ductilityValue * 1.5)

	armor = armor ^ curve
	losArmor = losArmor ^ curve

	-- ACE's existing penetration-probability curve, retained for compatibility.
	local armorLimit = losArmor * effectiveness
	local breachProb = math.Clamp((caliber / armorLimit - 1.3) / 5.7, 0, 1)
	local penProb = (math.Clamp(
		1 / (1 + math.exp(-43.9445 * (maxPenetration / armorLimit - 1))),
		0.0015,
		0.9985
	) - 0.0015) / 0.997

	if breachProb > math.random() and maxPenetration > armorLimit then
		HitRes.Damage = FrArea * resiliance * damageMult * ductilityMult
		HitRes.Overkill = maxPenetration - armorLimit
		HitRes.Loss = armorLimit / maxPenetration
		return HitRes
	elseif penProb > math.random() then
		local Penetration = math.min(maxPenetration, armorLimit)
		local brittleMult = Material.penetrationDamageMult or 1

		HitRes.Damage = (Penetration / losArmorHealth / effectiveness) ^ 2
			* FrArea * resiliance * damageMult * ductilityMult * brittleMult
		HitRes.Overkill = maxPenetration - Penetration
		HitRes.Loss = Penetration / maxPenetration
		return HitRes
	end

	local Penetration = math.min(maxPenetration, armorLimit)
	HitRes.Damage = (Penetration / losArmorHealth / effectiveness)
		* FrArea * resiliance * damageMult * ductilityMult
	HitRes.Overkill = 0
	HitRes.Loss = 1

	return HitRes
end

local Graphene = {}
Graphene.id = "Graph"
Graphene.name = "Graphene Composite"
Graphene.sname = "Graphene"
Graphene.desc = "Advanced layered graphene composite. High kinetic resistance for its density, but brittle and costly. Ballistic performance is a science-fiction extrapolation."
Graphene.year = 2023

-- Graphite/graphene bulk density: 2.26 g/cm^3; RHA reference: 7.85 g/cm^3.
Graphene.massMod = 2.26 / 7.85
Graphene.curve = 1

-- Hypothetical tank-scale composite values, not measured graphene armor constants.
Graphene.effectiveness = 2.1
Graphene.HEATeffectiveness = 1.7
Graphene.HEeffectiveness = 0.9
Graphene.resiliance = 2.5
Graphene.HEATresiliance = 1.5
Graphene.HEresiliance = 2.5
Graphene.penetrationDamageMult = 2

Graphene.spallresist = 1
Graphene.spallmult = 0.7
Graphene.ArmorMul = 1
Graphene.NormMult = 1

if SERVER then
	function Graphene.ArmorResolution(Entity, armor, losArmor, losArmorHealth, maxPenetration, FrArea, caliber, damageMult, Type)
		return makeArmorResolution(Graphene, Entity, armor, losArmor, losArmorHealth, maxPenetration, FrArea, caliber, damageMult, Type)
	end
end

ACE.ArmorTypes[Graphene.id] = Graphene

local Aerogel = {}
Aerogel.id = "Aero"
Aerogel.name = "Silica Aerogel Composite"
Aerogel.sname = "Aerogel"
Aerogel.desc = "Ultra-light silica aerogel composite with excellent thermal insulation, but very poor ballistic strength. Thermal insulation does not equal shaped-charge jet resistance."
Aerogel.year = 2023

-- NASA Ames lists 100 kg/m^3 as a typical silica-aerogel density.
Aerogel.massMod = 100 / 7850
Aerogel.curve = 1

-- Aerogel has no credible high-velocity armor equivalency. Values deliberately
-- keep it weak; HEAT is better than its near-zero KE rating, not better than Ti.
Aerogel.effectiveness = 0.02
Aerogel.HEATeffectiveness = 0.5
Aerogel.HEeffectiveness = 0.1
Aerogel.resiliance = 8
Aerogel.HEATresiliance = 2
Aerogel.HEresiliance = 6
Aerogel.penetrationDamageMult = 3

Aerogel.spallresist = 1
Aerogel.spallmult = 0.7
Aerogel.ArmorMul = 0.23
Aerogel.NormMult = 0.5

if SERVER then
	function Aerogel.ArmorResolution(Entity, armor, losArmor, losArmorHealth, maxPenetration, FrArea, caliber, damageMult, Type)
		return makeArmorResolution(Aerogel, Entity, armor, losArmor, losArmorHealth, maxPenetration, FrArea, caliber, damageMult, Type)
	end
end

ACE.ArmorTypes[Aerogel.id] = Aerogel

local Diamond = {}
Diamond.id = "Diam"
Diamond.name = "Diamond Composite"
Diamond.sname = "Diamond"
Diamond.desc = "Ultra-hard diamond-based composite. Excellent kinetic resistance, but extremely brittle and vulnerable to damage after penetration."
Diamond.year = 2023

-- Diamond density: 3.51 g/cm^3; RHA reference: 7.85 g/cm^3.
Diamond.massMod = 3.51 / 7.85
Diamond.curve = 0.99

-- Hardness is not itself a ballistic protection multiplier. These are conservative
-- fictional armor coefficients chosen above ordinary ceramic, not diamond constants.
Diamond.effectiveness = 2.4
Diamond.HEATeffectiveness = 1.5
Diamond.HEeffectiveness = 1.0
Diamond.resiliance = 18
Diamond.HEATresiliance = 5
Diamond.HEresiliance = 12
Diamond.penetrationDamageMult = 4

Diamond.spallresist = 1
Diamond.spallmult = 3.5
Diamond.ArmorMul = 1.8
Diamond.NormMult = 1.5

if SERVER then
	function Diamond.ArmorResolution(Entity, armor, losArmor, losArmorHealth, maxPenetration, FrArea, caliber, damageMult, Type)
		return makeArmorResolution(Diamond, Entity, armor, losArmor, losArmorHealth, maxPenetration, FrArea, caliber, damageMult, Type)
	end
end

ACE.ArmorTypes[Diamond.id] = Diamond
