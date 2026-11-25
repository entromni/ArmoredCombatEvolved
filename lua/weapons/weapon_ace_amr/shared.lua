SWEP.PrintName = "Anti Materiel Rifle"
SWEP.Base = "weapon_ace_base"
SWEP.Category = "ACE Weapons"
SWEP.SubCategory = "Special"
SWEP.Purpose = "Handheld 40mm anti materiel rifle"
SWEP.Instructions = "Left click to fire. Right click to scope. Press R with a round chambered to open the ammunition menu."
SWEP.Spawnable = true
SWEP.Slot = 3 --Which inventory column the weapon appears in
SWEP.SlotPos = 1 --Priority in which the weapon appears, 1 tries to put it at the top

--Resolved at call time so the base weapon's table is available no matter how
--the loader reorders weapon files.
local BASE_WEAPON = "weapon_ace_base"

local function GetBaseWeapon()
	return weapons.Get( BASE_WEAPON ) or {}
end

--Main settings--
SWEP.FireRate = 1 --Rounds per second

SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 10
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "XBowBolt"
SWEP.Primary.Sound = "ace_weapons/sweps/multi_sound/amr_multi.mp3"
SWEP.Primary.LightScale = 200 --Muzzleflash light radius
SWEP.Primary.BulletCount = 1 --Number of bullets to fire each shot, used for shotguns

SWEP.ReloadSound = "Weapon_Pistol.Reload" --Sound other players hear when you reload - this is NOT your first-person sound
										--Most models have a built-in first-person reload sound
SWEP.ReticuleSize = 10
SWEP.ZoomFOV = 20
SWEP.HasScope = true --True if the weapon has a sniper-style scope


--Recoil (crosshair movement) settings--
--"Heat" is a number that represents how long you've been firing, affecting how quickly your crosshair moves upwards
SWEP.HeatReductionDelay = 0.1
SWEP.HeatReductionRate = 600 --Heat loss per second when not firing
--SWEP.HeatReductionDelay = 0.3 --Delay after firing before beginning to reduce heat
SWEP.HeatPerShot = 1 --Heat generated per shot
SWEP.HeatMax = 1 --Maximum heat - determines max rate at which recoil is applied to eye angles
				--Also determines point at which random spread is at its highest intensity
				--HeatMax divided by HeatPerShot gives you how many shots until you reach MaxSpread

SWEP.AngularRecoil = 1	--Amount of angular recoil
			--HeatMax divided by HeatPerShot gives you how many shots until you reach MaxSpread

SWEP.RecoilSideBias = 0.1 --How much the recoil is biased to one side proportional to vertical recoil
						--Positive numbers bias to the right, negative to the left

SWEP.ZoomRecoilBonus = 0.5 --Reduce recoil by this amount when zoomed or scoped
SWEP.CrouchRecoilBonus = 0.5 --Reduce recoil by this amount when crouching
SWEP.ViewPunchAmount = 30 --Degrees to punch the view upwards each shot - does not actually move crosshair, just a visual effect


--Spread (aimcone) settings--
SWEP.BaseSpread = 0 --First-shot random spread, in degrees
SWEP.MaxSpread = 1 --Maximum added random spread from heat value, in degrees
					--If HeatMax is 0 this will be ignored and only BaseSpread will be taken into account (AT4 for example)
SWEP.MovementSpread = 4 --Increase aimcone to this many degrees when sprinting at full speed
SWEP.UnscopedSpread = 0.9 --Spread, in degrees, when unscoped with a scoped weapon

SWEP.CarrySpeedMul			= 0.7


--Model settings--
SWEP.ViewModelFlip = false
SWEP.ViewModel = "models/weapons/v_sniper.mdl"
SWEP.WorldModel = "models/weapons/w_sniper.mdl"
SWEP.HoldType = "ar2"
SWEP.DeployDelay = 1 --Time before you can fire after deploying the weapon
SWEP.CSMuzzleFlashes = false


--Ammunition--
--Every round is built through ACE's round conversion pipeline, the same one
--ammo crates use, against a real gun definition. The rifle is chambered in
--40mm HMG (lua/acf/shared/guns/heavymachinegun.lua), which is what sets the
--case length, powder capacity and conversion modifiers.
local AMMO_GUN_ID = "40mmHMG"
local MAX_PARAMETER = 1000
local METERS_TO_INCHES = 39.37
local BLAST_RADIUS_EXPONENT = 0.33
local BLAST_RADIUS_SCALE = 8
local SLUG_LIMIT_VELOCITY = 999999
local STATE_SEPARATOR = "|"
local NET_APPLY_AMMO = "ACE_AMR_ApplyAmmo"

SWEP.AmmoNetChannel = NET_APPLY_AMMO

SWEP.DefaultAmmo = "HVAP"
SWEP.AmmoOrder = { "HVAP", "AP", "APHE", "APDS", "APFSDS", "HP", "HE", "HEAT", "SM" }

--Presets only seed the editable values below; everything can be tuned after
--picking one. `clamped` maps an editor field to the field the round returns
--once it has clamped the value against the case/projectile limits.
SWEP.AmmoDefs = {
	HVAP = {
		label = "HVAP",
		name = "High-Velocity Armor Piercing",
		blurb = "Tungsten dart in a light sabot. The best kinetic penetrator this case can throw, and the rifle's default round.",
		colour = Color(120, 220, 140),
		preset = { PropLength = 20, ProjLength = 14, Data5 = 0.25 },
		clamped = { Data5 = "SCalMult" },
		sliders = {
			{ key = "Data5", title = "Sub-calibre size", suffix = "x", decimals = 2, min = 0.25, max = 1,
				info = function( data )
					local dart = math.floor((data.Caliber or 4) * math.min(data.SCalMult or 0.25, 1) * 10 + 0.5)
					return dart .. " mm dart"
				end },
		},
	},

	AP = {
		label = "AP",
		name = "Armour Piercing",
		blurb = "Solid full-bore shot. Heavy and cheap, but at 40 mm it trades badly against HVAP.",
		colour = Color(230, 200, 110),
		preset = { PropLength = 20, ProjLength = 14 },
		sliders = {},
	},

	APHE = {
		label = "APHE",
		name = "Armour Piercing High Explosive",
		blurb = "Armour-piercing shot with a bursting charge and a base fuze. Penetrates, then detonates inside.",
		colour = Color(235, 170, 100),
		preset = { PropLength = 20, ProjLength = 14, Data5 = 12, Data6 = 0.02 },
		clamped = { Data5 = "FillerVol", Data6 = "DetDelay" },
		sliders = {
			{ key = "Data5", title = "HE filler volume", suffix = "cm3", decimals = 1, min = 0, max = function( data ) return data.MaxFillerVol or 0 end,
				info = function( data ) return math.floor((data.FillerMass or 0) * 1000 + 0.5) .. " g filler" end },
			{ key = "Data6", title = "Base fuze delay", suffix = "s", decimals = 3, min = 0, max = 1,
				info = function( data ) return math.floor((data.DetDelay or 0) * 1000 + 0.5) .. " ms" end },
		},
	},

	APDS = {
		label = "APDS",
		name = "Armour Piercing Discarding Sabot",
		blurb = "Sub-calibre sabot round. The 40 mm pen-area penalty keeps it behind HVAP despite the higher velocity.",
		colour = Color(140, 200, 230),
		preset = { PropLength = 20, ProjLength = 14, Data5 = 0.50 },
		clamped = { Data5 = "SCalMult" },
		sliders = {
			{ key = "Data5", title = "Sub-calibre size", suffix = "x", decimals = 2, min = 0.28, max = 1,
				info = function( data )
					local dart = math.floor((data.Caliber or 4) * math.min(data.SCalMult or 0.5, 1) * 10 + 0.5)
					return dart .. " mm dart"
				end },
		},
	},

	APFSDS = {
		label = "APFSDS",
		name = "Armour Piercing Fin-Stabilised Discarding Sabot",
		blurb = "Long-rod fin-stabilised dart. Better downrange than APDS, same 40 mm trade-off up close.",
		colour = Color(120, 180, 240),
		preset = { PropLength = 20, ProjLength = 14, Data5 = 0.45 },
		clamped = { Data5 = "SCalMult" },
		sliders = {
			{ key = "Data5", title = "Sub-calibre size", suffix = "x", decimals = 2, min = 0.25, max = 1,
				info = function( data )
					local dart = math.floor((data.Caliber or 4) * math.min(data.SCalMult or 0.45, 1) * 10 + 0.5)
					return dart .. " mm dart"
				end },
		},
	},

	HP = {
		label = "HP",
		name = "Hollow Point",
		blurb = "Expanding projectile. Devastating against infantry, pointless against anything armoured.",
		colour = Color(230, 120, 110),
		preset = { PropLength = 20, ProjLength = 14, Data5 = 20 },
		clamped = { Data5 = "CavVol" },
		sliders = {
			{ key = "Data5", title = "Hollow point cavity", suffix = "cm3", decimals = 1, min = 0, max = function( data ) return data.MaxCavVol or 0 end,
				info = function( data ) return math.floor((data.ExpCaliber or 0) * 10 + 0.5) .. " mm expanded" end },
		},
	},

	HE = {
		label = "HE",
		name = "High Explosive",
		blurb = "Maximum filler for the calibre. Shreds soft targets, light cover and open infantry.",
		colour = Color(245, 150, 70),
		preset = { PropLength = 16, ProjLength = 16, Data5 = 90 },
		clamped = { Data5 = "FillerVol" },
		sliders = {
			{ key = "Data5", title = "HE filler volume", suffix = "cm3", decimals = 1, min = 0, max = function( data ) return data.MaxFillerVol or 0 end,
				info = function( data ) return math.floor((data.FillerMass or 0) * 1000 + 0.5) .. " g filler" end },
		},
	},

	HEAT = {
		label = "HEAT",
		name = "High Explosive Anti-Tank",
		blurb = "Shaped charge. Penetration is lost with air gap, so hit bare armour rather than skirts.",
		colour = Color(240, 110, 70),
		preset = { PropLength = 16, ProjLength = 16, Data5 = 90, Data6 = 35 },
		clamped = { Data5 = "FillerVol", Data6 = "ConeAng" },
		sliders = {
			{ key = "Data5", title = "Warhead filler volume", suffix = "cm3", decimals = 1, min = 0, max = function( data ) return data.MaxFillerVol or 0 end,
				info = function( data ) return math.floor((data.FillerMass or 0) * 1000 + 0.5) .. " g filler" end },
			{ key = "Data6", title = "Cone angle", suffix = "deg", decimals = 0, min = 0, max = function( data ) return math.ceil(data.MaxConeAng or 0) end,
				info = function( data, swep )
					local stats = swep:GetRoundStats( data )
					return math.floor( ( stats.slugPenetration or 0 ) + 0.5 ) .. " mm slug"
				end },
		},
	},

	SM = {
		label = "SM",
		name = "Smoke / White Phosphorus",
		blurb = "Smoke screen with an optional white phosphorus payload and a timed fuze. Fuze 0 detonates on impact.",
		colour = Color(200, 200, 200),
		preset = { PropLength = 16, ProjLength = 16, Data5 = 80, Data6 = 0, Data7 = 0 },
		clamped = { Data5 = "FillerVol", Data6 = "WPVol", Data7 = "FuseLength" },
		sliders = {
			{ key = "Data5", title = "Smoke filler volume", suffix = "cm3", decimals = 1, min = 0, max = function( data ) return data.MaxSmokeVol or 0 end,
				info = function( data ) return math.floor((data.FillerMass or 0) * 1000 + 0.5) .. " g smoke" end },
			{ key = "Data6", title = "WP filler volume", suffix = "cm3", decimals = 1, min = 0, max = function( data ) return data.MaxWPVol or 0 end,
				info = function( data ) return math.floor((data.WPMass or 0) * 1000 + 0.5) .. " g WP" end },
			{ key = "Data7", title = "Timed fuze", suffix = "s", decimals = 2, min = 0, max = 5,
				info = function( data ) return (data.FuseLength or 0) > 0 and "timed" or "impact" end },
		},
	},
}


--- Returns a fresh parameter table seeded from an ammunition preset.
-- @param ammoType string Round type, e.g. "HEAT".
-- @return table Editable parameters for the round builder.
function SWEP:GetPresetParams( ammoType )
	local def = self.AmmoDefs[ammoType]

	if not def then
		ammoType = self.DefaultAmmo
		def = self.AmmoDefs[ammoType]
	end

	local params = { Type = ammoType, Data5 = 0, Data6 = 0, Data7 = 0 }

	for key, value in pairs( def.preset ) do
		params[key] = value
	end

	return params
end


--- Converts the editable parameters into a ready-to-fire ACE bullet table.
-- Runs on both realms: the server gets physics data, the client also gets the
-- GUI range fields the ammunition menu reads.
-- @param params table Editable round parameters (see SWEP.AmmoDefs).
-- @return table|nil BulletData, or nil when the round type is unavailable.
function SWEP:BuildAmmoData( params )
	local round = ACE.RoundTypes[params.Type]
	if not round then return nil end

	local playerData = {
		Id = AMMO_GUN_ID,
		Type = params.Type,
		PropLength = params.PropLength or 0,
		ProjLength = params.ProjLength or 0,
		Data5 = params.Data5 or 0,
		Data6 = params.Data6 or 0,
		Data7 = params.Data7 or 0,
		Tracer = 1,
		TwoPiece = 0,
	}

	local ok, data = pcall( round.convert, nil, playerData )
	if not ok or type( data ) ~= "table" then return nil end

	return data
end


--- Rebuilds SWEP.BulletData and the fields the fake crate reads from the
-- current SWEP.AmmoParams. Falls back to the default preset if conversion fails.
function SWEP:RefreshBulletData()
	local data = self:BuildAmmoData( self.AmmoParams )

	if not data or not data.Caliber then
		self.AmmoParams = self:GetPresetParams( self.DefaultAmmo )
		data = self:BuildAmmoData( self.AmmoParams )
	end

	if not data or not data.Caliber then return end

	local def = self.AmmoDefs[self.AmmoParams.Type] or self.AmmoDefs[self.DefaultAmmo]

	--convert() only returns Id/Type in its SERVER branch, and the client branch
	--only carries the GUI ranges, so stamp both fields on in either realm.
	data.Id = AMMO_GUN_ID
	data.Type = self.AmmoParams.Type
	data.AmmoType = data.Type
	data.Colour = def.colour

	self.BulletData = data
	self.Type = data.Type
	self.Caliber = data.Caliber
	self.ProjMass = data.ProjMass
	self.FillerMass = data.FillerMass
	self.BoomFillerMass = data.BoomFillerMass or data.FillerMass or 0
	self.DragCoef = data.DragCoef
	self.Tracer = data.Tracer
	self.Colour = data.Colour

	if SERVER and self.UpdateFakeCrate then
		self:UpdateFakeCrate()
	end
end


--- Collects the numbers the HUD/notification/menu display for a converted round.
-- @param data table Round data from ACE.RoundTypes[type].convert.
-- @return table Stats table (velocity, penetration, slugPenetration, blast, filler, projectileMass, roundMass, roundLength).
function SWEP:GetRoundStats( data )
	local stats = {}
	stats.velocity = data.MuzzleVel or 0
	stats.projectileMass = data.ProjMass or 0
	stats.propellantMass = data.PropMass or 0
	stats.filler = data.FillerMass or 0
	stats.roundMass = stats.projectileMass + stats.propellantMass
	stats.roundLength = (data.PropLength or 0) + (data.ProjLength or 0) + (data.Tracer or 0)
	stats.blast = stats.filler > 0 and stats.filler ^ BLAST_RADIUS_EXPONENT * BLAST_RADIUS_SCALE or 0

	if data.PenArea and stats.velocity > 0 then
		local energy = ACE.Kinetic( stats.velocity * METERS_TO_INCHES, stats.projectileMass, data.LimitVel or SLUG_LIMIT_VELOCITY )
		stats.penetration = ACE.CalcPenetration( energy, data.PenArea, 1 )
	end

	if data.SlugPenArea and data.SlugMass and data.SlugMV then
		local energy = ACE.Kinetic( data.SlugMV * METERS_TO_INCHES, data.SlugMass, SLUG_LIMIT_VELOCITY )
		stats.slugPenetration = ACE.CalcPenetration( energy, data.SlugPenArea, 1 )
	end

	return stats
end


--- One-line summary of the currently loaded round, used by the deploy notification.
-- @return string Human readable ammunition summary.
function SWEP:GetAmmoSummary()
	local ammoType = self.AmmoParams and self.AmmoParams.Type or self.DefaultAmmo
	local def = self.AmmoDefs[ammoType]

	if not def or not self.BulletData then return "40mm ammunition" end

	local stats = self:GetRoundStats( self.BulletData )
	local label = "40mm " .. def.label

	if ammoType == "SM" then
		if self.BulletData.SMRadiusMax then
			return string.format( "%s - %d m/s - smoke %.1f-%.1f m for %.0f s", label, math.floor( stats.velocity ),
				self.BulletData.SMRadiusMin or 0, self.BulletData.SMRadiusMax or 0, self.BulletData.SMLife or 0 )
		end

		return string.format( "%s - %d m/s - smoke round", label, math.floor( stats.velocity ) )
	end

	if ammoType == "HE" then
		return string.format( "%s - %d m/s - %d g filler - %.1f m blast", label, math.floor( stats.velocity ),
			math.floor( stats.filler * 1000 + 0.5 ), stats.blast )
	end

	if ammoType == "HEAT" then
		return string.format( "%s - %d m/s - %d mm slug - %d g filler", label, math.floor( stats.velocity ),
			math.floor( ( stats.slugPenetration or 0 ) + 0.5 ), math.floor( stats.filler * 1000 + 0.5 ) )
	end

	if ammoType == "APHE" then
		return string.format( "%s - %d m/s - %d mm pen - %d g filler", label, math.floor( stats.velocity ),
			math.floor( ( stats.penetration or 0 ) + 0.5 ), math.floor( stats.filler * 1000 + 0.5 ) )
	end

	if ammoType == "HP" then
		return string.format( "%s - %d m/s - %d g projectile", label, math.floor( stats.velocity ),
			math.floor( stats.projectileMass * 1000 + 0.5 ) )
	end

	return string.format( "%s - %d m/s - %d mm pen - %d g", label, math.floor( stats.velocity ),
		math.floor( ( stats.penetration or 0 ) + 0.5 ), math.floor( stats.projectileMass * 1000 + 0.5 ) )
end


--- Applies a round type and its parameters, rebuilding the bullet and syncing it.
-- @param ammoType string Round type to load.
-- @param values table Raw { PropLength, ProjLength, Data5, Data6, Data7 } values.
-- @param owner Player|nil Owner to notify.
-- @return boolean True when the round was accepted.
function SWEP:ApplyAmmo( ammoType, values, owner )
	if not self.AmmoDefs[ammoType] then return false end

	local function sanitize( value )
		value = tonumber( value )
		if not value or value ~= value then return 0 end
		return math.Clamp( value, 0, MAX_PARAMETER )
	end

	self.AmmoParams = {
		Type = ammoType,
		PropLength = sanitize( values[1] ),
		ProjLength = sanitize( values[2] ),
		Data5 = sanitize( values[3] ),
		Data6 = sanitize( values[4] ),
		Data7 = sanitize( values[5] ),
	}

	self:RefreshBulletData()
	self:PushAmmoState()
	self:DoAmmoStatDisplay()

	if IsValid( owner ) and owner:IsPlayer() then
		owner:EmitSound( "items/ammo_pickup.wav", 60, math.random( 95, 105 ) )
	end

	return true
end


--- Serialises the current ammunition parameters into a network string.
function SWEP:PushAmmoState()
	if not SERVER then return end

	local params = self.AmmoParams
	if not params then return end

	self:SetNWString( "ACE_AMR_State", table.concat( {
		params.Type,
		params.PropLength,
		params.ProjLength,
		params.Data5,
		params.Data6,
		params.Data7,
	}, STATE_SEPARATOR ) )
end


--- Rebuilds the client-side bullet data from the networked ammunition string.
-- @param state string Serialised ammunition state from the server.
function SWEP:ApplyAmmoState( state )
	if not state or state == "" then return end

	local parts = string.Explode( STATE_SEPARATOR, state )
	local ammoType = parts[1]

	if not self.AmmoDefs[ammoType] then return end

	self.AmmoParams = {
		Type = ammoType,
		PropLength = tonumber( parts[2] ) or 0,
		ProjLength = tonumber( parts[3] ) or 0,
		Data5 = tonumber( parts[4] ) or 0,
		Data6 = tonumber( parts[5] ) or 0,
		Data7 = tonumber( parts[6] ) or 0,
	}

	self:RefreshBulletData()
end


function SWEP:InitBulletData()
	self.AmmoParams = self.AmmoParams or self:GetPresetParams( self.DefaultAmmo )
	self:RefreshBulletData()
end


function SWEP:DoAmmoStatDisplay()
	if not self.BulletData or not IsValid( self:GetOwner() ) then return end

	ACE_SendNotification( self:GetOwner(), self:GetAmmoSummary(), 6 )
end


function SWEP:OnThink()
	if not CLIENT then return end

	if self.AmmoMenuHeldBlock then
		local owner = self:GetOwner()

		if not IsValid( owner ) or not owner:KeyDown( IN_RELOAD ) then
			self.AmmoMenuHeldBlock = false
		end
	end

	local state = self:GetNWString( "ACE_AMR_State", "" )
	if state == "" or state == self.SyncedAmmoState then return end

	self.SyncedAmmoState = state
	self:ApplyAmmoState( state )
end


function SWEP:Reload()
	--R only opens the menu. GMod calls Reload() repeatedly while the key is
	--held, so toggling here would flicker the frame open and shut.
	if CLIENT and self:Clip1() >= self.Primary.ClipSize and self.OpenAmmoMenu then
		self:OpenAmmoMenu()
		return
	end

	return GetBaseWeapon().Reload( self )
end


function SWEP:Holster()
	if CLIENT and self.CloseAmmoMenu then
		self:CloseAmmoMenu()
	end

	return GetBaseWeapon().Holster( self )
end


function SWEP:OnRemove()
	if CLIENT and self.CloseAmmoMenu then
		self:CloseAmmoMenu()
	end

	local base = GetBaseWeapon()
	if base.OnRemove then
		base.OnRemove( self )
	end
end
