-- ACE continuous sci-fi laser weapon. It consumes charge from linked Electric fuel tanks
-- instead of consuming physical ammunition. The normal ACE gun entity is retained so the
-- weapon stays in the ACE gun menu and uses the standard heat / overheat damage system.

if not SERVER then return end

AddCSLuaFile("autorun/client/cl_ace_laser_sound.lua")

local LASER_ID = "50mmSL"
local LINK_RANGE = 512
local FIRE_INTERVAL = 0.1
local CHARGE_TIME = 3
-- kWh consumed per second at Power=1.0 (Power ramps from 0.55 to 1.8).
-- 4.8 kWh/s at the 50 mm anchor and power=1.0; scales with caliber area.
-- No heat-based power reduction: heat only raises ACE overheat damage.
local ENERGY_RATE = 4.8
local CALIBER_ANCHOR = 5.0

local function GetCaliberScale(Gun)
	return math.max((Gun.Caliber or CALIBER_ANCHOR) / CALIBER_ANCHOR, 0.1)
end

local function IsLaser(Gun)
	return IsValid(Gun) and Gun:GetClass() == "acf_gun" and (Gun.Class == "SFL" or Gun.Id == LASER_ID)
end

local function IsBatteryLinkValid(Gun, Tank)
	if not IsValid(Tank) or Tank:GetClass() ~= "acf_fueltank" then return false end
	if Tank.FuelType ~= "Electric" then return false end

	local Range = LINK_RANGE * (Gun.LinkRangeMul or 1)
	return ACE_InDist(Gun:GetPos(), Tank:GetPos(), Range)
end

local function IsBatteryOperational(Gun, Tank)
	return IsBatteryLinkValid(Gun, Tank)
		and Tank.Legal and Tank.Active
		and not Tank.CookingOff and not Tank.CookoffSpent and not Tank.Exploding
		and (Tank.Fuel or 0) > 0
end

local function SaveBatteryLinks(Gun)
	if not duplicator or not duplicator.StoreEntityModifier then return end

	local Links = {}
	for _, Tank in ipairs(Gun.LaserBatteryLink or {}) do
		if IsValid(Tank) then
			Links[#Links + 1] = Tank:EntIndex()
		end
	end

	if #Links > 0 then
		duplicator.StoreEntityModifier(Gun, "ACE_LaserBatteryLink", { entities = Links })
	elseif Gun.EntityMods then
		Gun.EntityMods.ACE_LaserBatteryLink = nil
	end
end

local function InstallGunLinkSupport()
	local Stored = scripted_ents.GetStored("acf_gun")
	local GunENT = Stored and Stored.t
	if not GunENT or GunENT.ACE_LaserLinkSupport then return end

	local OriginalLink = GunENT.Link
	local OriginalUnlink = GunENT.Unlink
	local OriginalPaste = GunENT.PostEntityPaste
	local OriginalHeatFunction = GunENT.Heat_Function

	GunENT.Link = function(Gun, Target)
		if IsLaser(Gun) and IsValid(Target) and Target:GetClass() == "acf_fueltank" then
			if Target.FuelType ~= "Electric" then
				return false, "The laser can only link to an ACE electric battery."
			end
			if not Target.Legal then return false, "This battery is illegal." end
			if Target.NoLinks then return false, "This battery cannot be linked." end
			if not ACE_InDist(Gun:GetPos(), Target:GetPos(), LINK_RANGE * (Gun.LinkRangeMul or 1)) then
				return false, "That battery is too far away to link."
			end

			Gun.LaserBatteryLink = Gun.LaserBatteryLink or {}
			for _, Existing in ipairs(Gun.LaserBatteryLink) do
				if Existing == Target then return false, "That battery is already linked." end
			end

			table.insert(Gun.LaserBatteryLink, Target)
			Target.Master = Target.Master or {}
			table.insert(Target.Master, Gun)
			SaveBatteryLinks(Gun)
			return true, "Electric battery linked to laser."
		end

		return OriginalLink(Gun, Target)
	end

	GunENT.Unlink = function(Gun, Target)
		if IsLaser(Gun) and Gun.LaserBatteryLink then
			local Found = false
			for Index = #Gun.LaserBatteryLink, 1, -1 do
				if Gun.LaserBatteryLink[Index] == Target then
					table.remove(Gun.LaserBatteryLink, Index)
					Found = true
				end
			end

			if Found then
				if IsValid(Target) and Target.Master then
					for Index = #Target.Master, 1, -1 do
						if Target.Master[Index] == Gun then
							table.remove(Target.Master, Index)
						end
					end
				end

				SaveBatteryLinks(Gun)
				return true, "Electric battery unlinked from laser."
			end
		end

		return OriginalUnlink(Gun, Target)
	end

	if OriginalPaste then
		GunENT.PostEntityPaste = function(Gun, Player, Entity, CreatedEntities)
			local LinkData = Entity.EntityMods and Entity.EntityMods.ACE_LaserBatteryLink
			OriginalPaste(Gun, Player, Entity, CreatedEntities)

			if IsLaser(Gun) and LinkData and istable(LinkData.entities) then
				timer.Simple(0, function()
					if not IsValid(Gun) then return end
					for _, OldIndex in ipairs(LinkData.entities) do
						local Linked = CreatedEntities[OldIndex]
						if IsValid(Linked) then Gun:Link(Linked) end
					end
				end)
			end
		end
	end

	if OriginalHeatFunction then
		GunENT.Heat_Function = function(Gun, ...)
			if not IsLaser(Gun) then
				return OriginalHeatFunction(Gun, ...)
			end

			-- Laser heat is generated continuously while the beam is actually
			-- powered. Do not use ACE_HeatFromGun's one-shot HeatFire pulse:
			-- its ordinary cooling path was leaving this weapon around 180 C.
			local Delta = math.Clamp(Gun.DeltaTime or 0, 0, 0.25)
			local Heat = Gun.Heat or ACE.AmbientTemp
			if Gun.ACELaserFiring then
				Heat = Heat + 45 * Delta -- 45 C/s; no thermal power throttling.
			else
				Heat = Heat - math.max(Heat - ACE.AmbientTemp, 0) * 0.1 * Delta
			end

			Gun.Heat = Heat
			Gun.IsOverheated = Heat > 200
			if Wire_TriggerOutput then
				Wire_TriggerOutput(Gun, "Heat", math.Round(Heat))
				Wire_TriggerOutput(Gun, "OverHeat", Gun.IsOverheated and 1 or 0)
			end
		end
	end

	GunENT.ACE_LaserLinkSupport = true
end

timer.Create("ACE_InstallLaserLinkSupport", 0.25, 20, InstallGunLinkSupport)

local function StopLaser(Gun, ResetCharge)
	Gun.ACELaserFiring = false
	Gun:SetNW2Bool("ACE_LaserActive", false)
	if ResetCharge then Gun.ACELaserCharge = 0 end
	Gun.ACELaserLastUpdate = nil
end

local function ConsumeBatteryCharge(Gun, Requested)
	local LinkList = Gun.LaserBatteryLink or {}
	local Available = 0

	for Index = #LinkList, 1, -1 do
		local Tank = LinkList[Index]
		if not IsBatteryLinkValid(Gun, Tank) then
			Gun:Unlink(Tank)
		elseif IsBatteryOperational(Gun, Tank) then
			Available = Available + math.max(Tank.Fuel or 0, 0)
		end
	end

	local ToConsume = math.min(Requested, Available)
	local Remaining = ToConsume

	for _, Tank in ipairs(LinkList) do
		if Remaining <= 0 then break end
		if IsBatteryOperational(Gun, Tank) then
			local Take = math.min(math.max(Tank.Fuel or 0, 0), Remaining)
			Tank.Fuel = math.max(Tank.Fuel - Take, 0)
			Remaining = Remaining - Take
			if Tank.UpdateFuelMass then Tank:UpdateFuelMass() end
		end
	end

	return ToConsume, Available
end

local function FireLaser(Gun)
	local Now = CurTime()
	Gun.NextFire = Now + FIRE_INTERVAL

	local Last = Gun.ACELaserLastUpdate
	local Delta = Last and math.Clamp(Now - Last, 0, 0.2) or FIRE_INTERVAL
	if Last and Now - Last > 0.25 then
		Gun.ACELaserCharge = 0
		Delta = FIRE_INTERVAL
	end
	Gun.ACELaserLastUpdate = Now

	local Charge = math.Clamp(((Gun.ACELaserCharge or 0) + Delta) / CHARGE_TIME, 0, 1)
	local Power = Lerp(Charge, 0.55, 1.8)
	local CaliberScale = GetCaliberScale(Gun)
	local CaliberAreaScale = CaliberScale * CaliberScale
	local Requested = ENERGY_RATE * Power * CaliberAreaScale * Delta
	local Supplied, Available = ConsumeBatteryCharge(Gun, Requested)

	if Supplied <= 0 or Delta <= 0 then
		Gun.Firing = false
		StopLaser(Gun, true)
		Gun:SetNW2Float("ACE_LaserBatteryCharge", Available)
		return false
	end

	local EffectiveDelta = Delta * math.Clamp(Supplied / math.max(Requested, 0.000001), 0, 1)
	Gun.ACELaserCharge = math.min((Gun.ACELaserCharge or 0) + EffectiveDelta, CHARGE_TIME)
	Charge = math.Clamp(Gun.ACELaserCharge / CHARGE_TIME, 0, 1)
	Power = Lerp(Charge, 0.55, 1.8)

	Gun.HeatFire = true
	Gun.ACELaserFiring = true
	Gun:SetNW2Bool("ACE_LaserActive", true)
	Gun:SetNW2Float("ACE_LaserBatteryCharge", math.max(Available - Supplied, 0))
	Gun:SetNW2Float("ACE_LaserPower", Power)

	local Start = Gun:LocalToWorld(Gun.Muzzle or vector_origin)
	local Direction = Gun:GetForward()
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
	Effect:SetMagnitude(CaliberScale)
	util.Effect("ace_laser_beam", Effect, true, true)

	if EffectiveDelta >= 0.015 and Trace.Hit and IsValid(Trace.Entity) and ACE.Check(Trace.Entity) then
		local Target = Trace.Entity
		local Fraction = math.Clamp(EffectiveDelta / FIRE_INTERVAL, 0, 1)
		-- 8x the previous energy delivery; the electrical draw is increased by the same factor.
		local BeamMass = 1.28 * Power * CaliberAreaScale * Fraction
		local Energy = ACE.Kinetic(900 * 39.37, BeamMass, 500)
		local Area = 0.65
		local HitAngle = math.deg(math.acos(math.Clamp(Trace.HitNormal:Dot(-Direction), -1, 1)))
		local Owner = IsValid(Gun.User) and Gun.User or Gun:CPPIGetOwner()

		-- Resolve the beam through ACE first so armor/material interaction and
		-- non-penetrating armor degradation remain authentic.
		local HealthBefore = Target.ACF and Target.ACF.Health
		local ArmourBefore = Target.ACF and Target.ACF.Armour
		local HitRes = ACE_Damage(Target, Energy, Area, HitAngle, Owner, Trace.PhysicsBone or 0, Gun, "HEAT")

		-- Lasers ablate structure/health much more aggressively than they wear
		-- down the armor value. Add extra structural damage after ACE's armor
		-- resolution, and only apply a fraction of the corresponding armor loss.
		-- This is not penetration: the beam still stops at the first traced hit.
		if HitRes and not HitRes.Kill and IsValid(Target) and Target.ACF
			and isnumber(HealthBefore) and isnumber(Target.ACF.Health)
			and isnumber(Target.ACF.MaxHealth) and Target.ACF.MaxHealth > 0
			and isnumber(ArmourBefore) and isnumber(Target.ACF.Armour) then
			local BaseDamage = math.max(HealthBefore - Target.ACF.Health, 0)
			local ExtraDamage = BaseDamage * 4 -- 5x total health damage versus ACE's resolved damage.
			local HealthAfter = math.max(Target.ACF.Health - ExtraDamage, 0)
			local ArmorAtHealth = Target.ACF.MaxArmour * (0.5 + HealthAfter / Target.ACF.MaxHealth / 2)
			local NaturalArmorDrop = math.max(Target.ACF.Armour - ArmorAtHealth, 0)

			Target.ACF.Health = HealthAfter
			Target.ACF.Armour = math.max(Target.ACF.Armour - NaturalArmorDrop * 0.2, 0)
			if Target.ACF.PrHealth then
				ACE.UpdateVisualHealth(Target)
			end
			Target.ACF.PrHealth = Target.ACF.Health

			if Target.ACF.Health <= 0 then
				HitRes.Kill = true
			end
		end

		if HitRes and HitRes.Kill and IsValid(Target) then
			ACE_APKill(Target, Direction, Energy.Kinetic)
		end
	end

	-- Keep the conventional gun shell path from consuming ammo or producing recoil.
	return false
end

hook.Add("ACE_FireShell", "ACE_SciFiLaserBatteryWeapon", function(Gun)
	if not IsLaser(Gun) then return end
	return FireLaser(Gun)
end)

timer.Create("ACE_SciFiLaserStateCleanup", 0.1, 0, function()
	local Now = CurTime()
	for _, Gun in ipairs(ents.FindByClass("acf_gun")) do
		if not IsLaser(Gun) then continue end
		if Gun.ACELaserLastUpdate and Now - Gun.ACELaserLastUpdate > 0.25 then
			StopLaser(Gun, true)
		end
	end
end)

hook.Add("EntityRemoved", "ACE_SciFiLaserBatteryUnlink", function(Entity)
	if Entity:GetClass() ~= "acf_fueltank" then return end
	for _, Gun in ipairs(ents.FindByClass("acf_gun")) do
		if IsLaser(Gun) and Gun.LaserBatteryLink then
			Gun:Unlink(Entity)
		end
	end
end)
