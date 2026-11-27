AddCSLuaFile()

local Round = table.Copy(ACE.RoundTypes.AP)

ACE.AmmoBlacklist.LASER = {
	"AC", "AL", "C", "HMG", "HW", "MG", "MO", "RAC", "SA", "SC", "GL",
	"ATR", "FGL", "SBC", "NAV", "mNAV", "RM", "AR", "ECM", "SAM", "AAM",
	"ASM", "BOMB", "FFAR", "UAR", "GBU", "ARTY"
}

Round.type = "Ammo"
Round.name = "[LASER] - Continuous Beam"
Round.model = "models/munitions/round_100mm_shot.mdl"
Round.desc = "Continuous yellow laser beam. Damage and beam intensity ramp up with sustained firing."
Round.netid = 31
Round.Type = "LASER"

function Round.create(_, BulletData)
	local Gun = BulletData.Gun
	if not IsValid(Gun) then return end

	local Now = CurTime()
	local LastShot = Gun.ACELaserLastShot or Now
	local Delta = Now - LastShot

	if Delta > 0.2 then
		Gun.ACELaserCharge = 0
		Delta = 0
	end

	Gun.ACELaserLastShot = Now
	Gun:SetNW2Bool("ACE_LaserActive", true)
	Gun.ACELaserCharge = math.min((Gun.ACELaserCharge or 0) + Delta, 3)

	local Charge = math.Clamp(Gun.ACELaserCharge / 3, 0, 1)
	local Power = Lerp(Charge, 0.55, 1.8)
	local Start = Gun:LocalToWorld(Gun.Muzzle or vector_origin)
	local Direction = BulletData.Flight:GetNormalized()
	local Range = 32768

	local Contraption = Gun.CFW_GetContraption and Gun:CFW_GetContraption()
	local Filter = Contraption and Contraption.BulletFilter or { Gun }
	Filter = table.Copy(Filter)
	Filter[#Filter + 1] = Gun

	local Trace = util.TraceLine({
		start = Start,
		endpos = Start + Direction * Range,
		filter = Filter,
		mask = MASK_SHOT
	})

	local End = Trace.HitPos or (Start + Direction * Range)
	local Effect = EffectData()
	Effect:SetStart(Start)
	Effect:SetOrigin(End)
	Effect:SetScale(Power)
	util.Effect("ace_laser_beam", Effect, true, true)

	if not Trace.Hit or not IsValid(Trace.Entity) then return end

	local Target = Trace.Entity
	if not ACE.Check(Target) then return end

	-- The beam's effective energy grows with sustained firing, then ACE's material
	-- resolution and health/armor degradation handle the impact like other damage.
	local BeamMass = 0.16 * Power
	local Energy = ACE.Kinetic(900 * 39.37, BeamMass, 500)
	local Area = 0.65
	local HitAngle = math.deg(math.acos(math.Clamp(Trace.HitNormal:Dot(-Direction), -1, 1)))
	local Owner = IsValid(Gun.User) and Gun.User or Gun:CPPIGetOwner()

	local HitRes = ACE_Damage(Target, Energy, Area, HitAngle, Owner, Trace.PhysicsBone or 0, Gun, "HEAT")
	if HitRes and HitRes.Kill and IsValid(Target) then
		ACE_APKill(Target, Direction, Energy.Kinetic)
	end
end

function Round.network(Crate, BulletData)
	Crate:SetNWString("AmmoType", Round.Type)
	Crate:SetNWString("AmmoID", BulletData.Id)
	Crate:SetNWFloat("Caliber", BulletData.Caliber)
	Crate:SetNWFloat("ProjMass", BulletData.ProjMass or 0)
	Crate:SetNWFloat("PropMass", BulletData.PropMass or 0)
	Crate:SetNWFloat("Tracer", 0)
	Crate:SetNWFloat("BulletModel", Round.model)
end

function Round.guicreate(Panel, Table)
	acemenupanel:AmmoSelect(ACE.AmmoBlacklist.LASER)
	ACE.UpperCommonDataDisplay()
	acemenupanel:AmmoSlider("PropLength", 0, 0, 1000, 3, "Propellant Length", "")
	acemenupanel:AmmoSlider("ProjLength", 0, 0, 1000, 3, "Projectile Length", "")
	ACE.CommonDataDisplay()
	Round.guiupdate(Panel, Table)
end

function Round.guiupdate(Panel)
	local PlayerData = {
		Id = acemenupanel.AmmoData.Data.id,
		Type = Round.Type,
		PropLength = acemenupanel.AmmoData.PropLength,
		ProjLength = acemenupanel.AmmoData.ProjLength,
		Tracer = acemenupanel.AmmoData.Tracer,
		TwoPiece = acemenupanel.AmmoData.TwoPiece
	}

	local Data = Round.convert(Panel, PlayerData)

	RunConsoleCommand("acemenu_data1", PlayerData.Id)
	RunConsoleCommand("acemenu_data2", PlayerData.Type)
	RunConsoleCommand("acemenu_data3", Data.PropLength)
	RunConsoleCommand("acemenu_data4", Data.ProjLength)
	RunConsoleCommand("acemenu_data10", Data.Tracer)
	RunConsoleCommand("acemenu_data11", Data.TwoPiece)

	acemenupanel:AmmoSlider("PropLength", Data.PropLength, Data.MinPropLength, Data.MaxTotalLength, 3,
		"Propellant Length", "Propellant Mass: " .. math.floor(Data.PropMass * 1000) .. " g")
	acemenupanel:AmmoSlider("ProjLength", Data.ProjLength, Data.MinProjLength, Data.MaxTotalLength, 3,
		"Projectile Length", "Projectile Mass: " .. math.floor(Data.ProjMass * 1000) .. " g")

	ACE.UpperCommonDataDisplay(Data, PlayerData)
	ACE.CommonDataDisplay(Data)
end

list.Set("APRoundTypes", Round.Type, Round)
ACE.RoundTypes[Round.Type] = Round
ACE.IdRounds[Round.netid] = Round.Type

if SERVER then
	hook.Add("ACE_FireShell", "ACE_LaserSuppressMuzzleFlash", function(Gun)
		if Gun.Id ~= "50mmSL" or Gun.ACELaserMuzzleSuppressed then return end

		Gun.ACELaserMuzzleSuppressed = true
		Gun.MuzzleEffect = function() end
	end)

	timer.Create("ACE_LaserActiveCleanup", 0.1, 0, function()
		local Now = CurTime()

		for _, Gun in ipairs(ents.FindByClass("acf_gun")) do
			if Gun.Id ~= "50mmSL" then continue end

			if (Gun.ACELaserLastShot or 0) < Now - 0.2 then
				Gun:SetNW2Bool("ACE_LaserActive", false)
			end
		end
	end)
end
