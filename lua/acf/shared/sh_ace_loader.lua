
-- Loads all files from shared folder
AddCSLuaFile()

ACE = ACE or {}

local GunClasses        = {}
local RackClasses       = {}
local RadarClasses      = {}

local GunTable          = {}
local RackTable         = {}
local Radars            = {}
local Tools             = {}

local AmmoTable         = {}
local LegacyAmmoTable   = {}

local EngineTable       = {}
local GearboxTable      = {}
local FuelTankTable     = {}
local FuelTankSizeTable = {}
local MuzzleFlashTable  = {}

local MobilityTable     = {}
local Crewseats         = {}
local Extras            = {}

local ExplosiveTable    = {}

local GSoundData        = {}
local ModelData         = {}
local MineData          = {}

-- setup base classes. This is necessary stuff if you want to setup a menu for a specific item.
-- Janky as fuck though.
local gun_base = {
	ent    = "acf_gun",
	type   = "Guns"
}
local ammo_base = {
	ent = "acf_ammo",
	type = "Ammo"
}
local engine_base = {
	ent    = "acf_engine",
	type   = "Engines"
}
local gearbox_base = {
	ent    = "acf_gearbox",
	type   = "Gearboxes",
	sound  = "vehicles/junker/jnk_fourth_cruise_loop2.wav"
}
local fueltank_base = {
	ent    = "acf_fueltank",
	type   = "FuelTanks"
}
local rack_base = {
	ent    = "acf_rack",
	type   = "Racks"
}
local radar_base = {
	ent    = "acf_missileradar",
	type   = "Radars"
}
local trackradar_base = {
	ent    = "ace_trackingradar",
	type   = "Radars"
}
local sonar_base = {
	ent    = "ace_sonar",
	type   = "Radars"
}
local irst_base = {
	ent    = "ace_irst",
	type   = "Radars"
}
local vheat_source_base = {
	ent    = "ace_vheat_source",
	type   = "Tools"
}

local crewseat_base = {
	type   = "Crewseats"
}

local extras_base = {
	type   = "Extras"
}

local explosive_base = {
	ent    = "ace_explosive",
	type   = "Explosives"
}

-- add gui stuff to base classes if this is client
-- more required stuff for the menu. Janky as fuck
if CLIENT then
	gun_base.guicreate           = function( _, Table ) ACE.GunGUICreate( Table )		end or nil
	gun_base.guiupdate           = function() return end

	engine_base.guicreate        = function( _, tbl ) ACE.EngineGUI_Update( tbl )		end or nil

	gearbox_base.guicreate       = function( _, tbl ) ACE.GearboxGUICreate( tbl )		end or nil
	gearbox_base.guiupdate       = function() return end

	fueltank_base.guicreate      = function( _, tbl ) ACE.FuelTankGUICreate( tbl )		end or nil
	fueltank_base.guiupdate      = function( _, tbl ) ACE.FuelTankGUIUpdate( tbl )		end or nil

	radar_base.guicreate         = function( _, Table ) ACE.RadarGUICreate( Table )	end
	radar_base.guiupdate         = function() return end

	trackradar_base.guicreate    = function( _, Table ) ACE.TrackRadarGUICreate( Table )  end or nil
	trackradar_base.guiupdate    = function() return end

	sonar_base.guicreate    = function( _, Table ) ACE.SonarGUICreate( Table )  end or nil
	sonar_base.guiupdate    = function() return end

	irst_base.guicreate          = function( _, Table ) ACE.IRSTGUICreate( Table )		end or nil
	irst_base.guiupdate          = function() return end

	vheat_source_base.guicreate  = function( _, Table ) ACE.VHeatSourceGUICreate( Table )	end or nil
	vheat_source_base.guiupdate  = function() return end

	crewseat_base.guicreate  = function( _, Table ) ACE.CrewMenuGUICreate( Table ) end or nil
	crewseat_base.guiupdate  = function() return end

	extras_base.guicreate    = function( _, Table ) ACE.ExtrasGUICreate( Table ) end or nil
	extras_base.guiupdate    = function() return end

	explosive_base.guicreate = function( _, Table ) ACE.ExplosiveGUICreate( Table ) end or nil
	explosive_base.guiupdate = function( _, Table ) ACE.ExplosiveGUIUpdate( Table ) end or nil
end

-- some factory functions for defining ents
-- Be patient. There are alot of functions here

--Gun class definition
function ACE_DefineGunClass( id, data )
	if (data.year or 0) < ACE.Year then
		data.id = id
		GunClasses[ id ] = data
	end
end

-- Crewseat definition
function ACE_DefineCrewseat( id, data )
	data.id = id
	table.Inherit( data, crewseat_base )
	Crewseats[ id ] = data
end

-- Extras definition (wind sensor, gforce meter, etc.)
function ACE_DefineExtras( id, data )
	data.id = id
	table.Inherit( data, extras_base )
	Extras[ id ] = data
end

-- Generic entity-definition entry point retained for shared metadata files.
function ACE_DefineEntity( id, data )
	if data.category == "Crew" then
		return ACE.DefineCrewseat(id, data)
	end

	return ACE.DefineExtras(id, data)
end

-- Gun definition
function ACE_DefineGun( id, data )
	if (data.year or 0) < ACE.Year then
		data.id = id
		data.round.id = id
		table.Inherit( data, gun_base )
		GunTable[ id ] = data
	end
end

-- Muzzleflash definition. The definitions are likely to be placed at the same location as the gun itself
function ACE_DefineMuzzleFlash(id, data)
	data.id = id
	MuzzleFlashTable[ id ] = data
end

function ACE_DefineAmmoCrate( id, data )
	data.id = id

	-- Backwards/forwards compatibility for legacy typo key.
	if data.Length == nil and data.Lenght ~= nil then
		data.Length = data.Lenght
	elseif data.Lenght == nil and data.Length ~= nil then
		data.Lenght = data.Length
	elseif data.Length ~= nil and data.Lenght ~= nil and data.Length ~= data.Lenght then
		-- Prefer canonical key when both are present but disagree.
		data.Lenght = data.Length
	end

	table.Inherit( data, ammo_base )
	AmmoTable[ id ] = data
end

-- Legacy Ammo crate definition
function ACE_DefineLegacyAmmoCrate( id, data )
	data.id = id
	LegacyAmmoTable[ id ] = data
end

-- Rack definition
function ACE_DefineRack( id, data )
	data.id = id
	table.Inherit( data, rack_base )
	RackTable[ id ] = data
end

-- Rack class definition
function ACE_DefineRackClass( id, data )
	data.id = id
	RackClasses[ id ] = data
end

--Engine definition
function ACE_DefineEngine( id, data )
	if (data.year or 0) < ACE.Year then
		local engineData = ACE.CalcEnginePerformanceData(data.torquecurve or ACE.GenericTorqueCurves[data.enginetype], data.torque, data.idlerpm, data.limitrpm)

		data.peaktqrpm    = engineData.peakTqRPM
		data.peakpower    = engineData.peakPower
		data.peakpowerrpm = engineData.peakPowerRPM
		data.peakminrpm   = engineData.powerbandMinRPM
		data.peakmaxrpm   = engineData.powerbandMaxRPM
		data.curvefactor  = (data.limitrpm - data.idlerpm) / data.limitrpm

		data.id = id
		table.Inherit( data, engine_base )
		EngineTable[ id ] = data
		MobilityTable[ id ] = data
	end
end

-- Gearbox definition
function ACE_DefineGearbox( id, data )
	data.id = id
	table.Inherit( data, gearbox_base )
	GearboxTable[ id ] = data
	MobilityTable[ id ] = data
end

-- fueltank definition
function ACE_DefineFuelTank( id, data )
	data.id = id
	table.Inherit( data, fueltank_base )
	FuelTankTable[ id ] = data
	MobilityTable[ id ] = data
end

-- fueltank size definition
function ACE_DefineFuelTankSize( id, data )
	data.id = id
	table.Inherit( data, fueltank_base )
	FuelTankSizeTable[ id ] = data
end

-- Radar definition
function ACE_DefineRadar( id, data )
	data.id = id
	table.Inherit( data, radar_base )
	Radars[ id ] = data
end

-- Explosive charge definition
function ACE_DefineExplosive( id, data )
	data.id = id
	table.Inherit( data, explosive_base )
	ExplosiveTable[ id ] = data
end

-- Radar Class definition
function ACE_DefineRadarClass( id, data )
	data.id = id
	RadarClasses[ id ] = data
end


-- Tracking Radar definition
function ACE_DefineTrackRadar( id, data )
	data.id = id
	table.Inherit( data, trackradar_base )
	Radars[ id ] = data
end

-- Tracking Radar Class definition
function ACE_DefineTrackRadarClass( id, data )
	data.id = id
	RadarClasses[ id ] = data
end

-- Sonar Array Class definition
function ACE_DefineSonarClass( id, data )
	data.id = id
	RadarClasses[ id ] = data
end

-- Sonar definition
function ACE_DefineSonar( id, data )
	data.id = id
	table.Inherit( data, sonar_base )
	Radars[ id ] = data
end

-- Tracking Radar definition
function ACE_DefineIRST( id, data )
	data.id = id
	table.Inherit( data, irst_base )
	Radars[ id ] = data
end

-- Tracking Radar Class definition
function ACE_DefineIRSTClass( id, data )
	data.id = id
	RadarClasses[ id ] = data
end

-- Virtual Heat Source definition
function ACE_DefineVHeatSource( id, data )
	data.id = id
	table.Inherit( data, vheat_source_base )
	Tools[ id ] = data
end

--Step 2: gather specialized sounds. Normally sounds that have associated sounds into it. Literally using the string path as id.
function ACE_DefineGunFireSound( id, data )
	data.id = id
	GSoundData[id] = data
end

-- The model definition. This is where you can "add" scalable models.
function ACE_DefineModelData( id, data )
	data.id = id
	ModelData[id] = data
	ModelData[data.Model] = data -- I will allow both model or fast name as id.
end

-- Where you define a new Mine
function ACE_DefineMine(id, data)
	data.id = id
	MineData[id] = data
end

-- Getters for guidance names, for use in missile definitions.
local function GetAllInTableExcept(tbl, list)

	for k, name in ipairs(list) do
		list[name] = k
		list[k] = nil
	end
	local ret = {}
	for name, _ in pairs(tbl) do
		if not list[name] then
			ret[#ret + 1] = name
		end
	end
	return ret
end

function ACE_GetAllGuidanceNames()

	local ret = {}
	for name, _ in pairs(ACE.Guidance) do
		ret[#ret + 1] = name
	end
	return ret
end

function ACE_GetAllGuidanceNamesExcept(list)
	return GetAllInTableExcept(ACE.Guidance, list)
end

-- Getters for fuse names, for use in missile definitions.
function ACE_GetAllFuseNames()

	local ret = {}
	for name, _ in pairs(ACE.Fuse) do
		ret[#ret + 1] = name
	end
	return ret
end

function ACE_GetAllFuseNamesExcept(list)
	return GetAllInTableExcept(ACE.Fuse, list)
end

-- Used by ACF Unofficial Extras, these need to exist before any definitions are loaded
if ACE_InstallLegacyGlobal then
	ACE_InstallLegacyGlobal( "ACF_DefineEngine", ACE_DefineEngine )
	ACE_InstallLegacyGlobal( "ACF_DefineGearbox", ACE_DefineGearbox )
	ACE_InstallLegacyGlobal( "ACF_DefineFuelTankSize", ACE_DefineFuelTankSize )
end

-- search for and load a bunch of files or whatever
--
do

	local Gpath = "acf/shared/"
	local folders = {
		"armor",
		"guns",
		"rounds",
		"missiles",
		"mines",
		"radars",
		"ammocrates",
		"engines",
		"gearboxes",
		"guidances",
		"fueltanks",
		"fuses",
		"sounds",
		"tools",
		"crewseats",
		"extras",
		"explosives"
	}

	for _, folder in ipairs(folders) do

		local folderData = file.Find( Gpath .. folder .. "/*.lua", "LUA" )
		for _, v in pairs( folderData ) do
			AddCSLuaFile( "acf/shared/" .. folder .. "/" .. v )
			include( "acf/shared/" .. folder .. "/" .. v )
		end

	end

end

-- now that the tables are populated, throw them in the acf ents list
ACE.Classes.GunClass        = GunClasses
ACE.Classes.Rack            = RackClasses
ACE.Classes.Radar           = RadarClasses

ACE.Weapons.Ammo            = AmmoTable --end ammo containers listing
ACE.Weapons.LegacyAmmo      = LegacyAmmoTable

ACE.Weapons.Guns            = GunTable
ACE.Weapons.Racks           = RackTable
ACE.Weapons.Engines         = EngineTable
ACE.Weapons.Gearboxes       = GearboxTable
ACE.Weapons.FuelTanks       = FuelTankTable
ACE.Weapons.FuelTanksSize   = FuelTankSizeTable
ACE.Weapons.Radars          = Radars
ACE.Weapons.Tools           = Tools
ACE.Weapons.Crewseats       = Crewseats
ACE.Weapons.Extras          = Extras
ACE.Weapons.Explosives      = ExplosiveTable
ACE.MuzzleFlashes           = MuzzleFlashTable

--Small reminder of Mobility table. Still being used in stuff like starfall/e2. This can change
ACE.Weapons.Mobility    = MobilityTable

ACE.GSounds.GunFire     = GSoundData
-- Continuous cannon caliber support. Added for the preset-interpolation size menu.
-- Existing definitions remain untouched and act as exact interpolation anchors.
-- Continuous caliber support for all ordinary gun classes.
-- Preset definitions remain exact anchors; interpolate only within the selected gun class.
function ACE.GetGunSubclasses(GunClass)
	local Subclasses = {}
	local Seen = {}
	for _, Definition in pairs(GunTable) do
		if Definition.gunclass == GunClass and not Definition.rack then
			local Name = Definition.subclass or "Standard"
			if not Seen[Name] then
				Seen[Name] = true
				Subclasses[#Subclasses + 1] = Name
			end
		end
	end
	table.sort(Subclasses)
	return Subclasses
end

function ACE.GetGunCaliberBounds(GunClass, Subclass)
	local Minimum, Maximum
	for _, Definition in pairs(GunTable) do
		local DefinitionSubclass = Definition.subclass or "Standard"
		if Definition.gunclass == GunClass and DefinitionSubclass == (Subclass or "Standard") and not Definition.rack and not Definition.ACE_CustomPreset and isnumber(Definition.caliber) then
			Minimum = not Minimum and Definition.caliber or math.min(Minimum, Definition.caliber)
			Maximum = not Maximum and Definition.caliber or math.max(Maximum, Definition.caliber)
		end
	end
	return Minimum, Maximum
end

function ACE.GetGunSubclassPreset(GunClass, Subclass, NearCaliber)
	local Best, Distance
	for _, Definition in pairs(GunTable) do
		local DefinitionSubclass = Definition.subclass or "Standard"
		if Definition.gunclass == GunClass and DefinitionSubclass == (Subclass or "Standard") and not Definition.rack and not Definition.ACE_CustomPreset and isnumber(Definition.caliber) then
			local Delta = math.abs(Definition.caliber - (NearCaliber or Definition.caliber))
			if not Distance or Delta < Distance then Best, Distance = Definition, Delta end
		end
	end
	return Best
end

function ACE.InterpolateGunPreset(DefinitionID, Caliber, Subclass)
	local Base = GunTable[DefinitionID]
	if not Base or Base.rack or not isnumber(Base.caliber) then return Base, 1, DefinitionID end
	Caliber = tonumber(Caliber)
	if not Caliber then return Base, 1, DefinitionID end
	Subclass = Subclass or Base.subclass or "Standard"

	-- Switch to a preset belonging to the requested subclass before calculating
	-- bounds or interpolating; different subclasses can have different models,
	-- weights, ROF, magazine configuration, and caliber coverage.
	local SubclassBase = ACE.GetGunSubclassPreset(Base.gunclass, Subclass, Caliber)
	if not SubclassBase then return Base, 1, DefinitionID end
	Base = SubclassBase

	local Anchors = {}
	for _, Definition in pairs(GunTable) do
		local DefinitionSubclass = Definition.subclass or "Standard"
		if Definition.gunclass == Base.gunclass and DefinitionSubclass == Subclass and not Definition.rack and not Definition.ACE_CustomPreset and isnumber(Definition.caliber) then
			Anchors[#Anchors + 1] = Definition
		end
	end
	table.sort(Anchors, function(A, B) return A.caliber < B.caliber end)
	if #Anchors == 0 then return Base, 1, Base.id end

	Caliber = math.Clamp(Caliber, Anchors[1].caliber, Anchors[#Anchors].caliber)
	-- Canonical size, so a gun and a crate set to the same number get the same ID:
	-- snap to a preset within 0.05 mm, otherwise use 0.1 mm steps (units are cm).
	for _, Anchor in ipairs(Anchors) do
		if math.abs(Caliber - Anchor.caliber) <= 0.005001 then
			-- The laser's 130 mm endpoint is a preset anchor, but it must still
			-- receive the same physical model scale as interpolated calibers.
			local ModelScale = Base.gunclass == "SFL" and Anchor.caliber / Anchors[1].caliber or 1
			return table.Copy(Anchor), ModelScale, Anchor.id
		end
	end
	Caliber = math.Round(Caliber, 2)

	local Lower, Upper
	for Index = 1, #Anchors - 1 do
		if Caliber > Anchors[Index].caliber and Caliber < Anchors[Index + 1].caliber then
			Lower, Upper = Anchors[Index], Anchors[Index + 1]
			break
		end
	end
	if not Lower or not Upper then return table.Copy(Base), 1, Base.id end

	local ClassID = string.gsub(string.upper(Base.gunclass), "[^%w]", "")
	local SubclassID = string.gsub(string.upper(Subclass), "[^%w]", "")
	local CaliberKey = math.Round(Caliber * 1000)
	local CustomID = string.format("ACE_Custom_%s_%s_%d", ClassID, SubclassID, CaliberKey)

	local Existing = rawget(GunTable, CustomID)
	if Existing then return Existing, Caliber / Lower.caliber, CustomID end

	local Fraction = (Caliber - Lower.caliber) / (Upper.caliber - Lower.caliber)
	local Result = table.Copy(Lower)
	local Discrete = { id = true, year = true, caliber = true, magsize = true, magreload = true }
	local function InterpolateTable(Target, A, B)
		for Key, ValueA in pairs(A) do
			local ValueB = B[Key]
			if isnumber(ValueA) and isnumber(ValueB) and not Discrete[Key] then
				Target[Key] = Lerp(Fraction, ValueA, ValueB)
			elseif istable(ValueA) and istable(ValueB) then
				Target[Key] = table.Copy(ValueA)
				InterpolateTable(Target[Key], ValueA, ValueB)
			end
		end
	end
	InterpolateTable(Result, Lower, Upper)

	Result.caliber = Caliber
	Result.model = Lower.model
	Result.subclass = Subclass
	Result.ACE_CustomPreset = true

	Result.id = CustomID
	-- Crates store round.id and only link to a gun with the same ID.
	if Result.round then Result.round.id = CustomID end
	Result.name = string.format("%.1fmm Custom %s (%s)", Caliber * 10, Base.gunclass, Subclass)

	GunTable[CustomID] = Result
	return Result, Caliber / Lower.caliber, CustomID
end

--- Rebuilds a custom caliber definition from its ID alone.
-- Needed for crate dupes, other clients and fresh server sessions.
-- @param ID string An "ACE_Custom_<class>_<subclass>_<caliber>" gun ID.
-- @return table|nil The registered definition, or nil if the ID is not valid.
function ACE.ResolveGunID(ID)
	if not isstring(ID) then return end

	local Existing = rawget(GunTable, ID)
	if Existing then return Existing end

	local ClassID, SubclassID, CaliberKey = string.match(ID, "^ACE_Custom_(%w+)_(%w+)_(%d+)$")
	if not ClassID then return end

	local Preset
	for _, Definition in pairs(GunTable) do
		if not Definition.rack and not Definition.ACE_CustomPreset
			and string.gsub(string.upper(Definition.gunclass), "[^%w]", "") == ClassID
			and string.gsub(string.upper(Definition.subclass or "Standard"), "[^%w]", "") == SubclassID then
			Preset = Definition
			break
		end
	end
	if not Preset then return end

	-- Interpolation clamps and rounds, so an out-of-range ID comes back different.
	ACE.InterpolateGunPreset(Preset.id, tonumber(CaliberKey) / 1000, Preset.subclass or "Standard")

	return rawget(GunTable, ID)
end

-- Any lookup of an unregistered custom ID (either realm) rebuilds it on demand.
setmetatable(GunTable, { __index = function(_, ID) return ACE.ResolveGunID(ID) end })

-- Continuous gearbox sizing. Works like the gun caliber support above: the preset
-- definitions are exact anchors, and sizes in between are interpolated within one subtype.
do
	-- Size of each stock model relative to the Medium model of the same family,
	-- measured from the model hulls. S/M/L models are uniform scales of one mesh.
	local ModelSizes = {
		["models/engines/linear_s.mdl"]        = { Size = 0.67, Layout = "Inline" },
		["models/engines/linear_m.mdl"]        = { Size = 1,    Layout = "Inline" },
		["models/engines/linear_l.mdl"]        = { Size = 1.67, Layout = "Inline" },
		["models/engines/transaxial_s.mdl"]    = { Size = 0.67, Layout = "Transaxial" },
		["models/engines/transaxial_m.mdl"]    = { Size = 1,    Layout = "Transaxial" },
		["models/engines/transaxial_l.mdl"]    = { Size = 1.67, Layout = "Transaxial" },
		["models/engines/t5small.mdl"]         = { Size = 0.67, Layout = "Straight-through" },
		["models/engines/t5med.mdl"]           = { Size = 1,    Layout = "Straight-through" },
		["models/engines/t5large.mdl"]         = { Size = 1.33, Layout = "Straight-through" },
		["models/engines/flywheelclutcht.mdl"] = { Size = 0.5,  Layout = "Straight-through" },
		["models/engines/flywheelclutchs.mdl"] = { Size = 0.75, Layout = "Straight-through" },
		["models/engines/flywheelclutchm.mdl"] = { Size = 1,    Layout = "Straight-through" },
		["models/engines/flywheelclutchb.mdl"] = { Size = 1.5,  Layout = "Straight-through" },
	}

	local LayoutOrder = { ["Inline"] = 1, ["Transaxial"] = 2, ["Straight-through"] = 3 }

	--- Size of a gearbox definition relative to Medium.
	-- @param Definition table A gearbox definition.
	-- @return number|nil The size, or nil if this gearbox cannot be scaled (unknown model).
	function ACE.GetGearboxSize(Definition)
		if Definition.ACE_Size then return Definition.ACE_Size end

		local Info = ModelSizes[string.lower(Definition.model or "")]
		return Info and Info.Size
	end

	--- The subtype a gearbox belongs to within its category.
	-- @param Definition table A gearbox definition.
	-- @return string A key that is shared by every size of the subtype.
	-- @return string The label shown in the menu.
	-- @return number The sort order within the category.
	function ACE.GetGearboxSubtype(Definition)
		local Info = ModelSizes[string.lower(Definition.model or "")]

		-- Gearboxes with unknown (addon) models stay as individual fixed entries.
		if not Info then return Definition.id, Definition.name or Definition.id, 100000 end

		local Label = Info.Layout
		local Order = LayoutOrder[Info.Layout] * 2

		if Definition.auto then
			Label = Definition.gears .. "-Speed, " .. Label
			Order = Order + Definition.gears * 100
		end

		if Definition.doubleclutch then
			Label = Label .. ", Dual Clutch"
			Order = Order + 1
		end

		return Label, Label, Order
	end

	local function IsPresetOf(Definition, Category, SubtypeKey)
		return not Definition.ACE_CustomPreset and Definition.category == Category
			and ACE.GetGearboxSubtype(Definition) == SubtypeKey
	end

	--- Preset sizes of one subtype, smallest first.
	-- @param Category string Gearbox category, such as "4-Speed".
	-- @param SubtypeKey string Key returned by ACE.GetGearboxSubtype.
	-- @return table Array of preset definitions.
	function ACE.GetGearboxAnchors(Category, SubtypeKey)
		local Anchors = {}

		for _, Definition in pairs(GearboxTable) do
			if IsPresetOf(Definition, Category, SubtypeKey) then
				Anchors[#Anchors + 1] = Definition
			end
		end

		table.sort(Anchors, function(A, B)
			local SizeA, SizeB = ACE.GetGearboxSize(A) or 1, ACE.GetGearboxSize(B) or 1
			if SizeA == SizeB then return A.id < B.id end
			return SizeA < SizeB
		end)

		return Anchors
	end

	--- All subtypes of a category, in menu order.
	-- @param Category string Gearbox category.
	-- @return table Array of { Key = string, Label = string, Order = number }.
	function ACE.GetGearboxSubtypes(Category)
		local Subtypes, Seen = {}, {}

		for _, Definition in pairs(GearboxTable) do
			if Definition.category == Category and not Definition.ACE_CustomPreset then
				local Key, Label, Order = ACE.GetGearboxSubtype(Definition)

				if not Seen[Key] then
					Seen[Key] = true
					Subtypes[#Subtypes + 1] = { Key = Key, Label = Label, Order = Order }
				end
			end
		end

		table.sort(Subtypes, function(A, B)
			if A.Order == B.Order then return A.Label < B.Label end
			return A.Order < B.Order
		end)

		return Subtypes
	end

	--- Returns the gearbox definition for any size of a preset's subtype.
	-- Weight, torque rating and shift time are interpolated between the two nearest presets.
	-- @param DefinitionID string ID of any gearbox in the wanted subtype.
	-- @param Size number Wanted size relative to Medium. Clamped to the preset range.
	-- @return table|nil The definition.
	-- @return number Model scale to apply to the definition's model.
	-- @return string ID of the definition.
	function ACE.InterpolateGearboxPreset(DefinitionID, Size)
		local Base = GearboxTable[DefinitionID]
		if not Base then return nil, 1, DefinitionID end

		Size = tonumber(Size)
		if not Size or not ACE.GetGearboxSize(Base) then return Base, Base.ACE_ModelScale or 1, Base.id end

		local Anchors = ACE.GetGearboxAnchors(Base.category, (ACE.GetGearboxSubtype(Base)))
		if #Anchors == 0 then return Base, Base.ACE_ModelScale or 1, Base.id end

		Size = math.Clamp(Size, ACE.GetGearboxSize(Anchors[1]), ACE.GetGearboxSize(Anchors[#Anchors]))

		-- Sizes use steps of 0.01 so the same slider value always gives the same ID.
		for _, Anchor in ipairs(Anchors) do
			if math.abs(Size - ACE.GetGearboxSize(Anchor)) <= 0.005001 then
				return Anchor, 1, Anchor.id
			end
		end
		Size = math.Round(Size, 2)

		local Lower, Upper
		for Index = 1, #Anchors - 1 do
			if Size > ACE.GetGearboxSize(Anchors[Index]) and Size < ACE.GetGearboxSize(Anchors[Index + 1]) then
				Lower, Upper = Anchors[Index], Anchors[Index + 1]
				break
			end
		end
		if not Lower then return Base, Base.ACE_ModelScale or 1, Base.id end

		local CustomID = string.format("ACE_CustomGB_%s_%d", Anchors[1].id, math.Round(Size * 100))

		local Existing = rawget(GearboxTable, CustomID)
		if Existing then return Existing, Existing.ACE_ModelScale, CustomID end

		local LowerSize = ACE.GetGearboxSize(Lower)
		local Fraction = (Size - LowerSize) / (ACE.GetGearboxSize(Upper) - LowerSize)
		local Result = table.Copy(Lower)

		local function Blend(Key, Decimals)
			if isnumber(Lower[Key]) and isnumber(Upper[Key]) then
				Result[Key] = math.Round(Lerp(Fraction, Lower[Key], Upper[Key]), Decimals)
			end
		end
		Blend("weight", 1)
		Blend("maxtq", 0)
		Blend("switch", 3)
		Blend("acepoints", 3)

		local _, SubtypeLabel = ACE.GetGearboxSubtype(Lower)
		if not Lower.auto then SubtypeLabel = Lower.category .. ", " .. SubtypeLabel end

		Result.id = CustomID
		Result.name = string.format("%s%s, %.2fx", Lower.auto and "Auto, " or "", SubtypeLabel, Size)
		Result.ACE_Size = Size
		Result.ACE_ModelScale = Size / LowerSize
		Result.ACE_CustomPreset = true

		GearboxTable[CustomID] = Result
		return Result, Result.ACE_ModelScale, CustomID
	end

	--- Rebuilds a custom size gearbox definition from its ID alone.
	-- Needed for dupes, other clients and fresh server sessions.
	-- @param ID string An "ACE_CustomGB_<smallest preset ID>_<size * 100>" gearbox ID.
	-- @return table|nil The registered definition, or nil if the ID is not valid.
	function ACE.ResolveGearboxID(ID)
		if not isstring(ID) then return end

		local Existing = rawget(GearboxTable, ID)
		if Existing then return Existing end

		local PresetID, SizeKey = string.match(ID, "^ACE_CustomGB_(.+)_(%d+)$")
		if not PresetID or not rawget(GearboxTable, PresetID) then return end

		-- Interpolation clamps and rounds, so an out-of-range ID comes back different.
		ACE.InterpolateGearboxPreset(PresetID, tonumber(SizeKey) / 100)

		return rawget(GearboxTable, ID)
	end

	-- Any lookup of an unregistered custom ID (either realm) rebuilds it on demand.
	-- Mobility is still read by E2/Starfall, which expect to find every spawned gearbox.
	-- Custom sizes are not stored there, so they stay out of its lists.
	setmetatable(GearboxTable, { __index = function(_, ID) return ACE.ResolveGearboxID(ID) end })
	setmetatable(MobilityTable, { __index = function(_, ID) return ACE.ResolveGearboxID(ID) end })
end

-- Keep the cannon-named functions as compatibility wrappers for existing code.
function ACE.GetCannonCaliberBounds()
	return ACE.GetGunCaliberBounds("C")
end

function ACE.InterpolateCannonPreset(DefinitionID, Caliber)
	return ACE.InterpolateGunPreset(DefinitionID, Caliber)
end

ACE.ModelData           = ModelData
ACE.MineData            = MineData
