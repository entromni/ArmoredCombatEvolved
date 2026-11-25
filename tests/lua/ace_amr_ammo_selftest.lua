-- Headless checks for weapon_ace_amr's ammunition builder.
-- Loads ACE's real round definitions and the rifle's shared file under LuaJIT
-- with GMod stubs, then exercises presets, clamping, sanitising and syncing.
-- Usage: luajit tests/lua/ace_amr_ammo_selftest.lua <ACE repo>

local root = assert(arg[1], "usage: ace_amr_ammo_selftest.lua <ACE repo>")

SERVER, CLIENT = false, true

function AddCSLuaFile() end
function include() end
function IsValid( entity ) return entity ~= nil end
function Color( r, g, b, a ) return { r = r, g = g, b = b, a = a or 255 } end
function ACE_SendNotification() end
function Vector( x, y, z ) return { x = x or 0, y = y or 0, z = z or 0 } end

table.Merge = table.Merge or function( target, source )
	for key, value in pairs( source ) do
		target[key] = value
	end
	return target
end

table.Copy = table.Copy or function( source )
	local copy = {}
	for key, value in pairs( source ) do
		copy[key] = value
	end
	return copy
end

math.Max = math.max
math.Min = math.min
math.Clamp = math.Clamp or function( value, minValue, maxValue )
	if value < minValue then return minValue end
	if value > maxValue then return maxValue end
	return value
end
math.Round = math.Round or function( value ) return math.floor( value + 0.5 ) end

string.Explode = function( separator, text )
	local result = {}
	local pattern = "([^" .. separator .. "]+)"
	for part in string.gmatch( text, pattern ) do
		result[#result + 1] = part
	end
	return result
end

list = { Set = function() end }
hook = { Add = function() end, Remove = function() end, Run = function() end }

ACE = {
	AmmoBlacklist = {},
	RoundTypes = {},
	IdRounds = {},
	Translation = setmetatable( {}, { __index = function() return { "name", "desc" } end } ),
	Weapons = { Guns = {} },
	Classes = { GunClass = { AC = { type = "Gun" }, HMG = { type = "Gun" } } },
}

--Constants copied from lua/autorun/acf_globals.lua
ACE.PBase = 1050
ACE.PScale = 1
ACE.MVScale = 0.5
ACE.PDensity = 1.6
ACE.PenAreaMod = 0.85
ACE.KEtoRHA = 0.25
ACE.KinFudgeFactor = 2.1
ACE.HEDensity = 1.65
ACE.HEPower = 8000
ACE.HEFrag = 2500
ACE.HEATMVScale = 0.75
ACE.HEATMVScaleTan = 0.75
ACE.ShellPenMul = 1
ACE.HEBlastPenetration = 3500

--Math copied from sh_ace_functions.lua and ace_roundfunctions.lua
local function MuzzleVelocity( propellant, mass )
	local energy = ACE.PBase * ( ( 1 + propellant ) ^ ACE.PScale - 1 )
	return ( ( energy * 2000 / mass ) ^ ACE.MVScale )
end

local function Kinetic( speed, mass, limitVel )
	limitVel = limitVel or 99999
	speed = speed / 39.37
	local energy = {}
	energy.Kinetic = ( mass * ( speed ^ 2 ) ) / 2000
	energy.Momentum = speed * mass
	local ke = ( mass * ( speed ^ ACE.KinFudgeFactor ) ) / 2000 + energy.Momentum
	energy.Penetration = math.max( ke - ( math.max( speed - limitVel, 0 ) ^ 2 ) / ( limitVel * 5 ) * ( ke / 200 ) ^ 0.95, ke * 0.1 )
	return energy
end

local function CalcPenetration( energy, penArea, penMul )
	local energyPen = type( energy ) == "table" and tonumber( energy.Penetration ) or tonumber( energy )
	local area = tonumber( penArea )
	if not energyPen or not area or area <= 0 then return 0 end
	local pen = ( energyPen / area ) * ACE.KEtoRHA
	if penMul then pen = pen * penMul end
	if pen ~= pen then return 0 end
	return math.max( pen, 0 )
end

local function RoundBaseGunpowder( playerData, data, serverData, guiData )
	local gunData = ACE.Weapons.Guns[playerData.Id]
	local bulletMax = gunData.round
	local gunClass = ACE.Classes.GunClass[gunData.gunclass] or {}
	local isMissile = gunClass.type == "missile"

	guiData.MaxTotalLength = bulletMax.maxlength
	data.BodyCaliber = gunData.caliber
	data.WarheadCaliber = data.BodyCaliber
	data.Caliber = data.WarheadCaliber
	data.FrArea = math.pi * ( data.Caliber / 2 ) ^ 2
	data.Tracer = playerData.Tracer > 0 and math.min( data.Caliber / 5, 3 ) or 0
	data.TwoPiece = playerData.TwoPiece > 0 and 1 or 0

	local propMax = ( bulletMax.propweight * 1000 / ACE.PDensity ) / data.FrArea
	local curLength = playerData.ProjLength + math.min( playerData.PropLength, propMax ) + data.Tracer

	guiData.MinPropLength = 0.01
	guiData.MaxPropLength = math.max( math.min( guiData.MaxTotalLength - curLength + playerData.PropLength, propMax ), guiData.MinPropLength )

	local minProjLength = bulletMax.minprojlength or gunData.minprojlength
	if minProjLength == nil then
		local minProjRatio = bulletMax.minprojratio or gunData.minprojratio
		if minProjRatio == nil then minProjRatio = isMissile and 0.5 or 1.5 end
		local minProjCaliber = isMissile and data.BodyCaliber or data.Caliber
		minProjLength = minProjCaliber * minProjRatio
	end

	guiData.MinProjLength = math.max( minProjLength, 0.01 )
	guiData.MaxProjLength = math.max( guiData.MaxTotalLength - curLength + playerData.ProjLength, guiData.MinProjLength )

	local ratio = math.min( 1, ( guiData.MaxTotalLength - data.Tracer ) / ( playerData.ProjLength + math.min( playerData.PropLength, propMax ) ) )

	data.ProjLength = math.Clamp( playerData.ProjLength * ratio, guiData.MinProjLength, guiData.MaxProjLength )
	data.PropLength = math.Clamp( playerData.PropLength * ratio, guiData.MinPropLength, guiData.MaxPropLength )

	data.PropMass = data.FrArea * ( data.PropLength * ACE.PDensity / 1000 )
	guiData.ProjVolume = data.FrArea * data.ProjLength
	data.RoundVolume = data.FrArea * ( data.ProjLength + data.PropLength )

	return playerData, data, serverData, guiData
end

local function RoundShellCapacity( momentum, frArea, caliber, projLength )
	local minWall = 0.2 + ( ( momentum / frArea ) ^ 0.7 ) / 50
	local length = math.max( projLength - minWall, 0 )
	local radius = math.max( ( caliber / 2 ) - minWall, 0 )
	return math.pi * radius ^ 2 * length, length, radius
end

ACE.MuzzleVelocity = MuzzleVelocity
ACE.Kinetic = Kinetic
ACE.CalcPenetration = CalcPenetration
ACE.RoundBaseGunpowder = RoundBaseGunpowder
ACE.RoundShellCapacity = RoundShellCapacity

ACE.Weapons.Guns["40mmHMG"] = {
	name = "40mm Heavy Machinegun",
	caliber = 4.0,
	gunclass = "HMG",
	round = { maxlength = 45, propweight = 0.9 },
}

--Load the rounds the rifle can chamber. AP must come first: HP aliases its blacklist.
for _, name in ipairs( { "ap", "aphe", "apds", "apfsds", "hvap", "hp", "he", "heat", "smoke" } ) do
	local ok, err = pcall( dofile, root .. "/lua/acf/shared/rounds/round" .. name .. ".lua" )
	assert( ok, "failed to load round" .. name .. ": " .. tostring( err ) )
end

--Load the weapon itself. GMod pre-populates SWEP.Primary/Secondary.
SWEP = { Primary = {}, Secondary = {} }

local baseClass = {
	Reload = function() end,
	Holster = function() return true end,
	Initialize = function() end,
	OnRemove = function() end,
}

DEFINE_BASECLASS = function()
	BaseClass = baseClass
end

local ok, err = pcall( dofile, root .. "/lua/weapons/weapon_ace_amr/shared.lua" )
assert( ok, "failed to load weapon_ace_amr shared.lua: " .. tostring( err ) )

SWEP.GetOwner = function() return nil end
SWEP.GetNWString = function() return "" end

local function AssertFinite( value, label )
	assert( type( value ) == "number", label .. " is not a number" )
	assert( value == value, label .. " is NaN" )
	assert( value ~= math.huge and value ~= -math.huge, label .. " is infinite" )
end

----------------------------------------------------------------------------
-- Default load
----------------------------------------------------------------------------
SWEP:InitBulletData()

assert( SWEP.BulletData, "InitBulletData produced no bullet data" )
assert( SWEP.BulletData.Caliber == 4.0, "expected a 40mm caliber, got " .. tostring( SWEP.BulletData.Caliber ) )
assert( SWEP.AmmoParams.Type == "HVAP", "default round should be HVAP" )

----------------------------------------------------------------------------
-- Every preset converts into a sane round
----------------------------------------------------------------------------
for _, ammoType in ipairs( SWEP.AmmoOrder ) do
	assert( SWEP.AmmoDefs[ammoType], "AmmoOrder entry without a definition: " .. ammoType )

	SWEP.AmmoParams = SWEP:GetPresetParams( ammoType )
	SWEP:RefreshBulletData()

	local data = SWEP.BulletData
	assert( data.Type == ammoType, "conversion returned the wrong type for " .. ammoType )

	local stats = SWEP:GetRoundStats( data )
	AssertFinite( stats.velocity, ammoType .. " velocity" )
	AssertFinite( stats.roundMass, ammoType .. " round mass" )
	AssertFinite( stats.roundLength, ammoType .. " round length" )

	assert( stats.velocity > 200 and stats.velocity < 2500, ammoType .. " velocity out of range: " .. stats.velocity )
	assert( stats.roundMass > 0, ammoType .. " has no mass" )
	assert( stats.roundLength <= ( data.MaxTotalLength or 45 ) + 0.001, ammoType .. " does not fit the case" )

	local summary = SWEP:GetAmmoSummary()
	assert( type( summary ) == "string" and #summary > 8, ammoType .. " summary too short" )
	print( string.format( "%-7s %s", ammoType, summary ) )
end

----------------------------------------------------------------------------
-- More propellant means more velocity
----------------------------------------------------------------------------
SWEP.AmmoParams = SWEP:GetPresetParams( "HVAP" )
SWEP:RefreshBulletData()
local slowVelocity = SWEP:GetRoundStats( SWEP.BulletData ).velocity

SWEP.AmmoParams.PropLength = 25
SWEP:RefreshBulletData()
local fastVelocity = SWEP:GetRoundStats( SWEP.BulletData ).velocity

assert( fastVelocity > slowVelocity, "adding propellant did not raise velocity" )

----------------------------------------------------------------------------
-- Filler volume drives blast
----------------------------------------------------------------------------
SWEP.AmmoParams = SWEP:GetPresetParams( "HE" )
SWEP.AmmoParams.Data5 = 20
SWEP:RefreshBulletData()
local smallBlast = SWEP:GetRoundStats( SWEP.BulletData ).blast

SWEP.AmmoParams.Data5 = 90
SWEP:RefreshBulletData()
local largeBlast = SWEP:GetRoundStats( SWEP.BulletData ).blast

assert( largeBlast > smallBlast, "more HE filler did not raise blast radius" )
assert( largeBlast > 0, "HE round has no blast" )

----------------------------------------------------------------------------
-- Oversized rounds are clamped to the case
----------------------------------------------------------------------------
SWEP.AmmoParams = { Type = "AP", PropLength = 500, ProjLength = 500, Data5 = 0, Data6 = 0, Data7 = 0 }
SWEP:RefreshBulletData()
assert( SWEP.BulletData.Caliber == 4.0, "oversized round failed to convert" )
assert( SWEP.BulletData.PropLength + SWEP.BulletData.ProjLength <= 45.001, "oversized round was not clamped to the case" )

----------------------------------------------------------------------------
-- ApplyAmmo sanitises hostile values
----------------------------------------------------------------------------
assert( SWEP:ApplyAmmo( "HEAT", { 1e9, -50, 1e9, -1, 1e9 }, nil ), "HEAT apply failed" )
assert( SWEP.AmmoParams.Type == "HEAT", "HEAT was not selected" )

for _, key in ipairs( { "PropLength", "ProjLength", "Data5", "Data6", "Data7" } ) do
	local value = SWEP.AmmoParams[key]
	AssertFinite( value, key )
	assert( value >= 0 and value <= 1000, key .. " was not sanitised: " .. tostring( value ) )
end

local beforeType = SWEP.AmmoParams.Type
assert( not SWEP:ApplyAmmo( "NOPE", { 1, 2, 3, 4, 5 }, nil ), "unknown round type was accepted" )
assert( SWEP.AmmoParams.Type == beforeType, "unknown round type changed the loaded round" )

----------------------------------------------------------------------------
-- Network state round-trip
----------------------------------------------------------------------------
SWEP:ApplyAmmoState( "SM|16|16|80|20|0" )
assert( SWEP.AmmoParams.Type == "SM", "state string did not select SM" )
assert( SWEP.BulletData.Type == "SM", "state string did not rebuild the bullet" )
assert( math.abs( SWEP.AmmoParams.Data5 - 80 ) < 0.001, "state string lost the smoke volume" )

SWEP:ApplyAmmoState( "BOGUS|1|2|3|4|5" )
assert( SWEP.AmmoParams.Type == "SM", "malformed state string should be ignored" )

----------------------------------------------------------------------------
-- Customised rounds differ from their preset
----------------------------------------------------------------------------
SWEP.AmmoParams = SWEP:GetPresetParams( "HVAP" )
SWEP:RefreshBulletData()
local presetSummary = SWEP:GetAmmoSummary()

SWEP.AmmoParams.ProjLength = 20
SWEP:RefreshBulletData()
local customSummary = SWEP:GetAmmoSummary()

assert( presetSummary ~= customSummary, "editing a preset did not change the summary" )

----------------------------------------------------------------------------
-- Server realm: apply, crate refresh and network state serialisation
----------------------------------------------------------------------------
SERVER, CLIENT = true, false

local publishedState
local crateUpdates = 0

SWEP.SetNWString = function( _, _, value ) publishedState = value end
SWEP.UpdateFakeCrate = function() crateUpdates = crateUpdates + 1; SWEP.BulletData.Crate = 1 end

assert( SWEP:ApplyAmmo( "APHE", { 20, 14, 12, 0.02, 0 }, nil ), "server APHE apply failed" )
assert( SWEP.BulletData.Type == "APHE", "server bullet type is wrong" )
assert( SWEP.BulletData.Caliber == 4.0, "server bullet is not 40mm" )
assert( crateUpdates > 0, "server never refreshed the fake crate" )
assert( type( publishedState ) == "string", "server never published the ammunition state" )

local parts = string.Explode( "|", publishedState )
assert( parts[1] == "APHE", "published state has the wrong type" )
assert( math.abs( ( tonumber( parts[2] ) or 0 ) - 20 ) < 0.001, "published state lost the propellant length" )
assert( math.abs( ( tonumber( parts[4] ) or 0 ) - 12 ) < 0.001, "published state lost the filler volume" )

--And the client can read that state back.
SERVER, CLIENT = false, true
SWEP:ApplyAmmoState( publishedState )
assert( SWEP.AmmoParams.Type == "APHE", "client could not read the server state" )
assert( SWEP.BulletData.Type == "APHE", "client bullet was not rebuilt from the state" )

print( "ACE AMR ammo LuaJIT self-test: PASS" )
