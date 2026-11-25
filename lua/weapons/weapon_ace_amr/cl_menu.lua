--[[---------------------------------------------------------
	40mm ammunition menu for weapon_ace_amr.

	Deliberately uses stock Derma widgets (DFrame, DListView, DNumSlider,
	DButton) with no custom skinning so the window matches the rest of the
	game's tool panels. Opened with the reload key while a round is chambered.
-----------------------------------------------------------]]

local MENU_WIDTH = 780
local MENU_HEIGHT = 500
local MARGIN = 10
local CONTENT_X = 350
local CONTENT_WIDTH = 420
local CONTENT_TOP = 34
local LIST_WIDTH = 330
local LIST_HEIGHT = 388
local FOOTER_TOP = 430
local SLIDER_ROW_HEIGHT = 42
local BUTTON_WIDTH = 110
local BUTTON_HEIGHT = 28
local SLIDER_PRECISION = 0.001

local COMMON_SLIDERS = {
	{
		key = "PropLength",
		title = "Propellant length",
		suffix = "cm",
		decimals = 2,
		min = function( data ) return data.MinPropLength or 0.01 end,
		max = function( data ) return math.max( ( data.MaxTotalLength or 45 ) - ( data.ProjLength or 0 ) - ( data.Tracer or 0 ), data.MinPropLength or 0.01 ) end,
		info = function( data ) return string.format( "%d g powder", math.floor( ( data.PropMass or 0 ) * 1000 + 0.5 ) ) end,
	},
	{
		key = "ProjLength",
		title = "Projectile length",
		suffix = "cm",
		decimals = 2,
		min = function( data ) return data.MinProjLength or 0.01 end,
		max = function( data ) return math.max( ( data.MaxTotalLength or 45 ) - ( data.PropLength or 0 ) - ( data.Tracer or 0 ), data.MinProjLength or 0.01 ) end,
		info = function( data ) return string.format( "%d g projectile", math.floor( ( data.ProjMass or 0 ) * 1000 + 0.5 ) ) end,
	},
}

local function PrettyUnit( unit )
	if unit == "cm3" then return "cm³" end
	if unit == "x" then return "×" end
	if unit == "deg" then return "°" end
	return unit or ""
end

local function CopyParams( params )
	local copy = { Type = params.Type }
	for key, value in pairs( params ) do
		copy[key] = value
	end
	return copy
end

local function MassParts( mass )
	if mass >= 1 then
		return string.format( "%.2f kg", mass )
	end

	return string.format( "%d g", math.floor( mass * 1000 + 0.5 ) )
end

local function VelocityPart( velocity )
	return string.format( "%d m/s", math.floor( velocity + 0.5 ) )
end

local function ResolveValue( value, data )
	if type( value ) == "function" then
		return value( data ) or 0
	end

	return value or 0
end

local function IsPreset( swep, params )
	local def = swep.AmmoDefs[params.Type]
	if not def then return false end

	for key, value in pairs( def.preset ) do
		if math.abs( ( params[key] or 0 ) - value ) > SLIDER_PRECISION then
			return false
		end
	end

	return true
end


----------------------------------------------------------------------------
-- Text builders
----------------------------------------------------------------------------

local function BuildRowBrief( swep, ammoType, params )
	local data = swep:BuildAmmoData( params or swep:GetPresetParams( ammoType ) )
	if not data then return "", "" end

	local stats = swep:GetRoundStats( data )
	local velocity = VelocityPart( stats.velocity )
	local effect

	if ammoType == "SM" then
		effect = data.SMRadiusMax and string.format( "smoke %.1f-%.1f m", data.SMRadiusMin or 0, data.SMRadiusMax ) or "smoke"
	elseif ammoType == "HE" then
		effect = string.format( "%.1f m blast", stats.blast )
	elseif ammoType == "HEAT" then
		effect = string.format( "%d mm slug", math.floor( ( stats.slugPenetration or 0 ) + 0.5 ) )
	else
		effect = string.format( "%d mm pen", math.floor( ( stats.penetration or 0 ) + 0.5 ) )
	end

	return velocity, effect
end


local function BuildStatRows( swep, ammoType, data )
	local stats = swep:GetRoundStats( data )
	local projectileMass = MassParts( stats.projectileMass )
	local roundMass = MassParts( stats.roundMass )

	if ammoType == "SM" then
		local smoke = data.SMRadiusMax and string.format( "%.1f-%.1f m", data.SMRadiusMin or 0, data.SMRadiusMax ) or "-"
		local wp = data.WPRadiusMax and data.WPRadiusMax > 0 and string.format( "%.1f m", data.WPRadiusMax ) or "none"

		return {
			{ title = "Muzzle velocity", value = VelocityPart( stats.velocity ) },
			{ title = "Smoke cloud", value = smoke },
			{ title = "Smoke lifetime", value = string.format( "%.0f s", data.SMLife or 0 ) },
			{ title = "White phosphorus", value = wp },
		}
	end

	if ammoType == "HE" then
		return {
			{ title = "Muzzle velocity", value = VelocityPart( stats.velocity ) },
			{ title = "Blast radius", value = string.format( "%.1f m", stats.blast ) },
			{ title = "HE filler", value = string.format( "%d g", math.floor( stats.filler * 1000 + 0.5 ) ) },
			{ title = "Round mass", value = roundMass },
		}
	end

	if ammoType == "HEAT" then
		return {
			{ title = "Muzzle velocity", value = VelocityPart( stats.velocity ) },
			{ title = "HEAT penetration", value = string.format( "%d mm", math.floor( ( stats.slugPenetration or 0 ) + 0.5 ) ) },
			{ title = "HE filler", value = string.format( "%d g", math.floor( stats.filler * 1000 + 0.5 ) ) },
			{ title = "Blast radius", value = string.format( "%.1f m", stats.blast ) },
		}
	end

	if ammoType == "APHE" then
		return {
			{ title = "Muzzle velocity", value = VelocityPart( stats.velocity ) },
			{ title = "Penetration", value = string.format( "%d mm", math.floor( ( stats.penetration or 0 ) + 0.5 ) ) },
			{ title = "HE filler", value = string.format( "%d g", math.floor( stats.filler * 1000 + 0.5 ) ) },
			{ title = "Round mass", value = roundMass },
		}
	end

	if ammoType == "HP" then
		return {
			{ title = "Muzzle velocity", value = VelocityPart( stats.velocity ) },
			{ title = "Expanded calibre", value = string.format( "%d mm", math.floor( ( data.ExpCaliber or 0 ) * 10 + 0.5 ) ) },
			{ title = "Projectile mass", value = projectileMass },
			{ title = "Round mass", value = roundMass },
		}
	end

	return {
		{ title = "Muzzle velocity", value = VelocityPart( stats.velocity ) },
		{ title = "Penetration", value = string.format( "%d mm", math.floor( ( stats.penetration or 0 ) + 0.5 ) ) },
		{ title = "Projectile mass", value = projectileMass },
		{ title = "Round mass", value = roundMass },
	}
end


----------------------------------------------------------------------------
-- Widget helpers (stock Derma only)
----------------------------------------------------------------------------

local function CreateStatRow( parent, index, width )
	local title = vgui.Create( "DLabel", parent )
	title:SetFont( "DermaDefault" )
	title:SetPos( 0, ( index - 1 ) * 18 )
	title:SetSize( width / 2, 16 )
	title:SetText( "" )

	local value = vgui.Create( "DLabel", parent )
	value:SetFont( "DermaDefault" )
	value:SetPos( width / 2, ( index - 1 ) * 18 )
	value:SetSize( width / 2, 16 )
	value:SetContentAlignment( 6 )
	value:SetText( "" )

	return { title = title, value = value }
end


local function CreateSliderRow( parent, sliderDef, onChange )
	local row = vgui.Create( "DPanel", parent )
	row:SetTall( SLIDER_ROW_HEIGHT )
	row:Dock( TOP )
	row:SetPaintBackground( false )

	local slider = vgui.Create( "DNumSlider", row )
	slider:Dock( TOP )
	slider:SetTall( 22 )
	slider:SetText( sliderDef.title .. " (" .. PrettyUnit( sliderDef.suffix ) .. ")" )
	slider:SetDecimals( sliderDef.decimals )
	slider:SetMin( 0 )
	slider:SetMax( 1 )
	slider:SetValue( 0 )

	slider.OnValueChanged = function( _, value )
		if slider.ACEIgnore then return end
		onChange( value )
	end

	local info = vgui.Create( "DLabel", row )
	info:Dock( BOTTOM )
	info:SetFont( "DermaDefault" )
	info:SetText( "" )

	row.Slider = slider
	row.Info = info

	row.SetRange = function( self, minValue, maxValue )
		local control = self.Slider
		control.ACEIgnore = true
		control:SetMin( minValue )
		control:SetMax( math.max( maxValue, minValue ) )
		control.ACEIgnore = false
	end

	row.SetValue = function( self, value )
		local control = self.Slider
		control.ACEIgnore = true
		control:SetValue( value )
		control.ACEIgnore = false
	end

	return row
end


----------------------------------------------------------------------------
-- Menu
----------------------------------------------------------------------------

--- Opens the ammunition menu for this rifle, or does nothing when already open.
function SWEP:OpenAmmoMenu()
	if self.AmmoMenuHeldBlock then return end
	if IsValid( self.AmmoMenuFrame ) then return end

	local owner = self:GetOwner()
	if not IsValid( owner ) or not owner:Alive() then return end

	gui.EnableScreenClicker( true )

	local frame = vgui.Create( "DFrame" )
	frame:SetSize( MENU_WIDTH, MENU_HEIGHT )
	frame:Center()
	frame:SetTitle( "40mm Ammunition" )
	frame:SetIcon( "icon16/bomb.png" )
	frame:SetSizable( false )
	frame:SetDraggable( true )
	frame:MakePopup()
	frame:SetDeleteOnClose( true )
	frame:SetKeyboardInputEnabled( true )

	self.AmmoMenuFrame = frame

	--GMod's engine eats Escape before panels see it (it opens the pause menu).
	--While our frame is open, intercept that, close ourselves instead and stop
	--the pause menu from opening. Shift+Escape still bypasses this by design.
	hook.Add( "OnPauseMenuShow", "ACE_AMR_AmmoMenu", function()
		if not IsValid( self.AmmoMenuFrame ) then return end

		self:CloseAmmoMenu()

		return false
	end )

	local selectedType = self.AmmoParams and self.AmmoParams.Type or self.DefaultAmmo
	if not self.AmmoDefs[selectedType] then
		selectedType = self.DefaultAmmo
	end

	local menu = {
		selected = selectedType,
		params = CopyParams( self.AmmoParams or self:GetPresetParams( self.DefaultAmmo ) ),
		rows = {},
		stats = {},
		drafts = {},
		ignoreSelect = false,
	}

	frame.OnClose = function()
		self:CloseAmmoMenu()
	end

	frame.OnKeyCodePressed = function( _, key )
		if key == KEY_ESCAPE then
			frame:Close()
		end
	end

	--Round type list
	local list = vgui.Create( "DListView", frame )
	list:SetPos( MARGIN, CONTENT_TOP )
	list:SetSize( LIST_WIDTH, LIST_HEIGHT )
	list:SetMultiSelect( false )
	list:AddColumn( "Round" )
	list:AddColumn( "Velocity" )
	list:AddColumn( "Effect" )

	menu.list = list

	for _, ammoType in ipairs( self.AmmoOrder ) do
		local def = self.AmmoDefs[ammoType]
		local velocity, effect = BuildRowBrief( self, ammoType, ammoType == menu.selected and self.AmmoParams or nil )
		local line = list:AddLine( def.label, velocity, effect )

		line.AmmoType = ammoType
	end

	function list:OnRowSelected( _, line )
		if menu.ignoreSelect then return end
		self.OwnerWeapon:SelectAmmoType( menu, line.AmmoType )
	end

	list.OwnerWeapon = self

	--Content column
	local content = vgui.Create( "DPanel", frame )
	content:SetPos( CONTENT_X, CONTENT_TOP )
	content:SetSize( CONTENT_WIDTH, LIST_HEIGHT )
	content:SetPaintBackground( false )

	local nameLabel = vgui.Create( "DLabel", content )
	nameLabel:SetFont( "DermaDefaultBold" )
	nameLabel:SetPos( 0, 0 )
	nameLabel:SetSize( CONTENT_WIDTH, 24 )
	nameLabel:SetText( "" )

	local chamberLabel = vgui.Create( "DLabel", content )
	chamberLabel:SetFont( "DermaDefault" )
	chamberLabel:SetPos( 0, 24 )
	chamberLabel:SetSize( CONTENT_WIDTH, 16 )
	chamberLabel:SetText( "Anti Materiel Rifle  -  40mm HMG chamber" )

	local blurbLabel = vgui.Create( "DLabel", content )
	blurbLabel:SetFont( "DermaDefault" )
	blurbLabel:SetWrap( true )
	blurbLabel:SetAutoStretchVertical( true )
	blurbLabel:SetPos( 0, 44 )
	blurbLabel:SetSize( CONTENT_WIDTH, 36 )
	blurbLabel:SetText( "" )

	local statsPanel = vgui.Create( "DPanel", content )
	statsPanel:SetPos( 0, 86 )
	statsPanel:SetSize( CONTENT_WIDTH, 76 )
	statsPanel:SetPaintBackground( false )

	for index = 1, 4 do
		menu.stats[index] = CreateStatRow( statsPanel, index, CONTENT_WIDTH )
	end

	menu.sliderContainer = vgui.Create( "DPanel", content )
	menu.sliderContainer:SetPos( 0, 168 )
	menu.sliderContainer:SetSize( CONTENT_WIDTH, LIST_HEIGHT - 168 )
	menu.sliderContainer:SetPaintBackground( false )

	menu.nameLabel = nameLabel
	menu.blurbLabel = blurbLabel

	--Footer
	local status = vgui.Create( "DLabel", frame )
	status:SetFont( "DermaDefaultBold" )
	status:SetPos( MARGIN, FOOTER_TOP + 4 )
	status:SetSize( MENU_WIDTH - MARGIN * 2 - BUTTON_WIDTH * 2 - 20, 20 )
	status:SetText( "" )
	menu.status = status

	local hint = vgui.Create( "DLabel", frame )
	hint:SetFont( "DermaDefault" )
	hint:SetPos( MARGIN, FOOTER_TOP + 26 )
	hint:SetSize( MENU_WIDTH - MARGIN * 2 - BUTTON_WIDTH * 2 - 20, 16 )
	hint:SetText( "Esc closes. Values apply to this rifle only; presets stay editable." )

	local resetButton = vgui.Create( "DButton", frame )
	resetButton:SetText( "Reset preset" )
	resetButton:SetSize( BUTTON_WIDTH, BUTTON_HEIGHT )
	resetButton:SetPos( MENU_WIDTH - MARGIN - BUTTON_WIDTH * 2 - 8, FOOTER_TOP )
	resetButton.DoClick = function()
		menu.drafts[menu.selected] = nil
		menu.params = self:GetPresetParams( menu.selected )
		self:RebuildAmmoSliders( menu )
		self:RefreshAmmoMenu( menu )
	end

	local applyButton = vgui.Create( "DButton", frame )
	applyButton:SetText( "Load round" )
	applyButton:SetSize( BUTTON_WIDTH, BUTTON_HEIGHT )
	applyButton:SetPos( MENU_WIDTH - MARGIN - BUTTON_WIDTH, FOOTER_TOP )
	applyButton.DoClick = function()
		self:SubmitAmmo( menu.params )
		frame:Close()
	end

	self.AmmoMenu = menu
	self:RebuildAmmoSliders( menu )
	self:RefreshAmmoMenu( menu )

	--Select the loaded round without triggering the click handler.
	menu.ignoreSelect = true
	for _, line in ipairs( list:GetLines() ) do
		if line.AmmoType == menu.selected then
			list:SelectItem( line )
		end
	end
	menu.ignoreSelect = false
end


--- Selects a round type in the editor.
-- @param menu table Menu state.
-- @param ammoType string Round type to edit.
function SWEP:SelectAmmoType( menu, ammoType )
	if not self.AmmoDefs[ammoType] then return end

	--Keep edits around while the player compares round types.
	if menu.selected and menu.selected ~= ammoType then
		menu.drafts[menu.selected] = CopyParams( menu.params )
	end

	menu.selected = ammoType

	local draft = menu.drafts[ammoType]

	if draft then
		menu.params = CopyParams( draft )
	elseif ammoType == ( self.AmmoParams and self.AmmoParams.Type ) then
		menu.params = CopyParams( self.AmmoParams )
	else
		menu.params = self:GetPresetParams( ammoType )
	end

	self:RebuildAmmoSliders( menu )
	self:RefreshAmmoMenu( menu )
end


--- Rebuilds the slider list for the selected round type.
-- @param menu table Menu state.
function SWEP:RebuildAmmoSliders( menu )
	menu.sliderContainer:Clear()
	menu.rows = {}

	local def = self.AmmoDefs[menu.selected] or self.AmmoDefs[self.DefaultAmmo]
	local sliders = {}

	for _, sliderDef in ipairs( COMMON_SLIDERS ) do
		sliders[#sliders + 1] = sliderDef
	end

	for _, sliderDef in ipairs( def.sliders or {} ) do
		sliders[#sliders + 1] = sliderDef
	end

	for _, sliderDef in ipairs( sliders ) do
		local row = CreateSliderRow( menu.sliderContainer, sliderDef, function( value )
			menu.params[sliderDef.key] = value
			self:RefreshAmmoMenu( menu )
		end )

		menu.rows[#menu.rows + 1] = { def = sliderDef, row = row }
	end
end


--- Recomputes the preview data and refreshes every widget.
-- @param menu table Menu state.
function SWEP:RefreshAmmoMenu( menu )
	local params = menu.params
	local data = self:BuildAmmoData( params )

	if not data then return end

	local def = self.AmmoDefs[params.Type] or self.AmmoDefs[self.DefaultAmmo]

	--The conversion clamps lengths and payloads against the case and the shell
	--walls. Mirror its results back into the editor so the sliders never lie.
	params.PropLength = data.PropLength or params.PropLength
	params.ProjLength = data.ProjLength or params.ProjLength

	for key, field in pairs( def.clamped or {} ) do
		local value = data[field]
		if type( value ) == "number" then
			params[key] = value
		end
	end

	for _, entry in ipairs( menu.rows ) do
		local sliderDef = entry.def
		local minValue = ResolveValue( sliderDef.min, data )
		local maxValue = ResolveValue( sliderDef.max, data )

		--A zero-width range would divide by zero inside DNumSlider, so widen it.
		if maxValue <= minValue then
			maxValue = minValue + ( sliderDef.decimals > 0 and 0.01 or 1 )
		end

		local value = math.Clamp( params[sliderDef.key] or minValue, minValue, maxValue )

		params[sliderDef.key] = value
		entry.row:SetRange( minValue, maxValue )
		entry.row:SetValue( value )
		entry.row.Info:SetText( sliderDef.info and sliderDef.info( data, self ) or "" )
	end

	local stats = BuildStatRows( self, params.Type, data )
	for index, stat in ipairs( menu.stats ) do
		stat.title:SetText( stats[index].title )
		stat.value:SetText( stats[index].value )
	end

	menu.nameLabel:SetText( def.name )
	menu.blurbLabel:SetText( def.blurb )

	local preset = IsPreset( self, params )
	local roundLength = ( data.PropLength or 0 ) + ( data.ProjLength or 0 ) + ( data.Tracer or 0 )
	local caseLength = data.MaxTotalLength or 45

	menu.status:SetText( string.format( "%s  -  %s  -  %.1f / %.0f cm case", def.label,
		preset and "preset" or "custom", roundLength, caseLength ) )
end


--- Sends the edited round to the server so it becomes the loaded ammunition.
-- @param params table Round parameters to load.
function SWEP:SubmitAmmo( params )
	net.Start( self.AmmoNetChannel )
	net.WriteEntity( self )
	net.WriteString( params.Type )
	net.WriteFloat( params.PropLength or 0 )
	net.WriteFloat( params.ProjLength or 0 )
	net.WriteFloat( params.Data5 or 0 )
	net.WriteFloat( params.Data6 or 0 )
	net.WriteFloat( params.Data7 or 0 )
	net.SendToServer()
end


--- Closes the ammunition menu if it is open.
function SWEP:CloseAmmoMenu()
	local frame = self.AmmoMenuFrame
	self.AmmoMenuFrame = nil
	self.AmmoMenu = nil
	self.AmmoMenuHeldBlock = false

	--Reload() is called every tick while the key is held. Block reopening until
	--the player releases it, otherwise Esc would instantly re-open the menu.
	local owner = self:GetOwner()
	if IsValid( owner ) and owner:KeyDown( IN_RELOAD ) then
		self.AmmoMenuHeldBlock = true
	end

	if IsValid( frame ) then
		frame:Remove()
	end

	hook.Remove( "OnPauseMenuShow", "ACE_AMR_AmmoMenu" )
	gui.EnableScreenClicker( false )
end
