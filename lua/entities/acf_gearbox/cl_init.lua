
include("shared.lua")

CreateClientConVar("ace_gearbox_info_while_seated", 0, true, false)

-- copied from base_wire_entity: DoNormalDraw's notip arg isn't accessible from ENT:Draw defined there.
function ENT:Draw()

	local lply = LocalPlayer()
	local hideBubble = not GetConVar("ace_gearbox_info_while_seated"):GetBool() and IsValid(lply) and lply:InVehicle()

	self.BaseClass.DoNormalDraw(self, false, hideBubble)
	Wire_Render(self)

	if self.GetBeamLength and (not self.GetShowBeam or self:GetShowBeam()) then
		-- Every SENT that has GetBeamLength should draw a tracer. Some of them have the GetShowBeam boolean
		Wire_DrawTracerBeam( self, 1, self.GetBeamHighlight and self:GetBeamHighlight() or false )
	end

end

-- Client physics is a visual/collision proxy. PhysicsInit replaces it and can
-- leave the new object at its default origin until CalcAbsolutePosition runs.
-- Synchronize immediately as well, so parented gearboxes and attached ropes do
-- not briefly (or persistently) resolve their endpoints at world origin.
local function SyncGearboxPhysics( Gearbox )
	local Phys = Gearbox:GetPhysicsObject()
	if not IsValid( Phys ) then return end

	Phys:SetPos( Gearbox:GetPos() )
	Phys:SetAngles( Gearbox:GetAngles() )
	Phys:EnableMotion( false )
	Phys:Sleep()
end

-- Applies custom size collision and visuals. Checked from Think so it also
-- covers late joiners, model changes and a client physics object that was lost.
local function UpdateGearboxScale( Gearbox )
	local Scale = Gearbox:GetNWFloat( "ACE_ModelScale", 1 )
	local Model = Gearbox:GetModel()

	-- Custom scaling must be explicitly cleared when returning to a stock size.
	-- Otherwise the old RenderMultiply matrix and custom client collision remain.
	if Scale == 1 then
		if Gearbox.ACE_AppliedScale or Gearbox.ACE_AppliedModel then
			-- Stock gearboxes have no client physics object.
			Gearbox:PhysicsDestroy()
			Gearbox:EnableCustomCollisions( false )
			Gearbox:DisableMatrix( "RenderMultiply" )

			local Mins, Maxs = Gearbox:GetModelBounds()
			Gearbox:SetRenderBounds( Mins, Maxs )
			Gearbox:DrawShadow( true )

			Gearbox.ACE_AppliedScale = nil
			Gearbox.ACE_AppliedModel = nil
		end

		return
	end

	-- The model can change at an anchor boundary while the numeric scale stays
	-- the same. Include the model in the cache key so its collision is rebuilt.
	if Gearbox.ACE_AppliedScale == Scale
	and Gearbox.ACE_AppliedModel == Model
	and IsValid( Gearbox:GetPhysicsObject() ) then return end

	if not Gearbox:ACE_ApplyScaledCollision( Scale ) then return end

	local Phys = Gearbox:GetPhysicsObject()
	if not IsValid( Phys ) then return end
	SyncGearboxPhysics( Gearbox )

	local Mat = Matrix()
	Mat:Scale( Vector( Scale, Scale, Scale ) )
	Gearbox:EnableMatrix( "RenderMultiply", Mat )
	Gearbox:SetRenderBounds( Gearbox:GetCollisionBounds() )
	Gearbox:DrawShadow( false )

	Gearbox.ACE_AppliedScale = Scale
	Gearbox.ACE_AppliedModel = Model
end

-- The client physics object does not follow the entity by itself.
-- Unscaled gearboxes return nothing and keep default behaviour.
function ENT:CalcAbsolutePosition( Position, Angles )
	if not self.ACE_AppliedScale then return end

	SyncGearboxPhysics( self )

	return Position, Angles
end

function ENT:Think()
	-- Match the gun's client order: let the base entity update first, then
	-- rebuild custom collision/render state from the latest networked model/scale.
	local Result = self.BaseClass.Think( self )

	UpdateGearboxScale( self )

	-- Link ropes anchored here appear to follow the client physics object, and
	-- CalcAbsolutePosition alone does not keep it moving (parented gearboxes).
	if self.ACE_AppliedScale then
		SyncGearboxPhysics( self )
		self:SetNextClientThink( CurTime() )
		return true
	end

	return Result
end

function ACE_GearboxGUICreate( Table )

	if not acemenupanel.Serialize then
		acemenupanel.Serialize = function( tbl, factor )
			local str = ""
			for i = 1,7 do
				str = str .. math.Round(tbl[i] * factor,1) .. ","
			end
			RunConsoleCommand( "acemenu_data9", str )
		end
	end

	if not acemenupanel.GearboxData then
		acemenupanel.GearboxData = {}
	end

	local SubtypeKey = ACE.GetGearboxSubtype( Table )

	-- Ratios are remembered per subtype, so they carry across sizes.
	local StateKey = Table.category .. "|" .. SubtypeKey

	if not acemenupanel.GearboxData[StateKey] then
		acemenupanel.GearboxData[StateKey] = {}
		acemenupanel.GearboxData[StateKey].GearTable = table.Copy( Table.geartable )
	end

	if Table.auto and not acemenupanel.GearboxData[StateKey].ShiftTable then
		acemenupanel.GearboxData[StateKey].ShiftTable = {10,20,30,40,50,60,70}
	end

	acemenupanel.CustomDisplay:EnableVerticalScrollbar( true )

	acemenupanel:CPanelText("Name", Table.name, "DermaDefaultBold")

	acemenupanel.CData.DisplayModel = vgui.Create( "DModelPanel", acemenupanel.CustomDisplay )
		acemenupanel.CData.DisplayModel:SetModel( Table.model )
		acemenupanel.CData.DisplayModel:SetCamPos( Vector( 250, 500, 250 ) )
		acemenupanel.CData.DisplayModel:SetLookAt( Vector( 0, 0, 0 ) )
		acemenupanel.CData.DisplayModel:SetFOV( 20 )
		acemenupanel.CData.DisplayModel:SetSize(acemenupanel:GetWide(),acemenupanel:GetWide())
		acemenupanel.CData.DisplayModel.LayoutEntity = function() end
	acemenupanel.CustomDisplay:AddItem( acemenupanel.CData.DisplayModel )

	-- Subtype selector: only shown when this gearbox type has more than one.
	local Subtypes = ACE.GetGearboxSubtypes( Table.category )
	local Size = ACE.GetGearboxSize( Table )

	if #Subtypes > 1 then
		local SubtypeCombo = vgui.Create( "DComboBox", acemenupanel.CustomDisplay )
		SubtypeCombo:SetSize( acemenupanel.CustomDisplay:GetWide(), 28 )
		SubtypeCombo:SetSortItems( false )
		for _, Subtype in ipairs( Subtypes ) do
			SubtypeCombo:AddChoice( Subtype.Label, Subtype.Key )
		end
		for _, Subtype in ipairs( Subtypes ) do
			if Subtype.Key == SubtypeKey then SubtypeCombo:SetValue( Subtype.Label ) end
		end
		SubtypeCombo.OnSelect = function( _, _, _, Key )
			if Key == SubtypeKey then return end
			local Anchors = ACE.GetGearboxAnchors( Table.category, Key )
			if not Anchors[1] then return end
			-- Keep the chosen size, clamped to what the new subtype supports.
			local Definition = ACE.InterpolateGearboxPreset( Anchors[1].id, Size or 1 )
			acemenupanel:UpdateDisplay( Definition )
		end
		acemenupanel.CustomDisplay:AddItem( SubtypeCombo )
	end

	local SizeSlider
	local Anchors = ACE.GetGearboxAnchors( Table.category, SubtypeKey )

	if Size and #Anchors > 1 then
		SizeSlider = vgui.Create( "DNumSlider", acemenupanel.CustomDisplay )
		SizeSlider:SetText( "Size (1.00 = Medium)" )
		SizeSlider:SetDark( true )
		SizeSlider:SetMin( ACE.GetGearboxSize( Anchors[1] ) )
		SizeSlider:SetMax( ACE.GetGearboxSize( Anchors[#Anchors] ) )
		SizeSlider:SetDecimals( 2 )
		SizeSlider:SetSize( acemenupanel.CustomDisplay:GetWide(), 35 )
		SizeSlider:SetValue( Size )
		acemenupanel.CustomDisplay:AddItem( SizeSlider )
	end

	acemenupanel:CPanelText("Desc", Table.desc) --Description (Name, Desc)

	if Table.auto and not acemenupanel.CData.UnitsInput then
		acemenupanel.CData.UnitsInput = vgui.Create( "DComboBox", acemenupanel.CustomDisplay )
			acemenupanel.CData.UnitsInput.ID = StateKey
			acemenupanel.CData.UnitsInput.Gears = Table.gears
			acemenupanel.CData.UnitsInput:SetSize( 60,22 )
			acemenupanel.CData.UnitsInput:SetTooltip( "If using the shift point generator, recalc after changing units." )
			acemenupanel.CData.UnitsInput:AddChoice( "KPH", 10.936, true )
			acemenupanel.CData.UnitsInput:AddChoice( "MPH", 17.6 )
			acemenupanel.CData.UnitsInput:AddChoice( "GMU", 1 )
			acemenupanel.CData.UnitsInput:SetDark( true )
			acemenupanel.CData.UnitsInput.OnSelect = function( panel, _, _, data )
				acemenupanel.Serialize( acemenupanel.GearboxData[panel.ID].ShiftTable, data )  --dot intentional
			end
		acemenupanel.CustomDisplay:AddItem(acemenupanel.CData.UnitsInput)
	end

	local GearTable = acemenupanel.GearboxData[StateKey].GearTable
	local FinalDrive = GearTable[10] or GearTable[-1] -- Slider 10 is the final drive

	if Table.cvt then
		ACE_GearsSlider(2, GearTable[2], StateKey)
		ACE_GearsSlider(3, GearTable[3] or GearTable[-3], StateKey, "Min Target RPM",true)
		ACE_GearsSlider(4, GearTable[4] or GearTable[-2], StateKey, "Max Target RPM",true)
		ACE_GearsSlider(10, FinalDrive, StateKey, "Final Drive")
		RunConsoleCommand( "acemenu_data1", 0.01 )
	else
		-- Slot 8 holds the reverse gear on automatics.
		for ID = 1, 9 do
			if GearTable[ID] and not (Table.auto and ID == 8) then
				ACE_GearsSlider(ID, GearTable[ID], StateKey)
				if Table.auto then
					ACE_ShiftPoint(ID, acemenupanel.GearboxData[StateKey].ShiftTable[ID], StateKey, "Gear " .. ID .. " upshift speed: ")
				end
			end
		end
		if Table.auto then
			ACE_GearsSlider(8, GearTable[8] or GearTable[-2], StateKey, "Reverse")
		end
		if FinalDrive then
			ACE_GearsSlider(10, FinalDrive, StateKey, "Final Drive")
		end
	end

	--
	local InvertButton = vgui.Create("DButton")
	InvertButton:SetText( "Invert Final drive" )
	InvertButton:SetIcon( "icon16/arrow_refresh.png" )
	InvertButton.DoClick = function()
		if acemenupanel.CData[10] then ---10 gear is the final drive

			local oldValue = acemenupanel.CData[10]:GetValue()
			acemenupanel.CData[10]:SetValue( oldValue * -1 )
		end
	end
	acemenupanel.CustomDisplay:AddItem(InvertButton)

	acemenupanel:CPanelText("Desc", Table.desc)
	acemenupanel:CPanelText("MaxTorque", "")
	acemenupanel:CPanelText("Weight", "")
	acemenupanel:CPanelText("SwitchTime", "")

	if Table.auto then
		acemenupanel:CPanelText( "ShiftPointGen", "Shift Point Generator:", "DermaDefaultBold" )

		if not acemenupanel.CData.ShiftGenPanel then
			acemenupanel.CData.ShiftGenPanel = vgui.Create( "DPanel" )
				acemenupanel.CData.ShiftGenPanel:SetPaintBackground( false )
				acemenupanel.CData.ShiftGenPanel:DockPadding( 4, 0, 4, 0 )
				acemenupanel.CData.ShiftGenPanel:SetTall( 60 )
				acemenupanel.CData.ShiftGenPanel:SizeToContentsX()
				acemenupanel.CData.ShiftGenPanel.Gears = Table.gears

			acemenupanel.CData.ShiftGenPanel.Calc = acemenupanel.CData.ShiftGenPanel:Add( "DButton" )
				acemenupanel.CData.ShiftGenPanel.Calc:SetText( "Calculate" )
				acemenupanel.CData.ShiftGenPanel.Calc:Dock( BOTTOM )
				acemenupanel.CData.ShiftGenPanel.Calc:SetTall( 20 )

				acemenupanel.CData.ShiftGenPanel.Calc.DoClick = function()
					local _, factor = acemenupanel.CData.UnitsInput:GetSelected()
					local mul = math.pi * acemenupanel.CData.ShiftGenPanel.RPM:GetValue() * acemenupanel.CData.ShiftGenPanel.Ratio:GetValue() * acemenupanel.CData[10]:GetValue() * acemenupanel.CData.ShiftGenPanel.Wheel:GetValue() / (60 * factor)
					for i = 1,acemenupanel.CData.ShiftGenPanel.Gears do
						acemenupanel.CData[10 + i].Input:SetValue( math.Round( math.abs( mul * acemenupanel.CData[i]:GetValue() ), 2 ) )
						acemenupanel.GearboxData[acemenupanel.CData.UnitsInput.ID].ShiftTable[i] = tonumber(acemenupanel.CData[10 + i].Input:GetValue())
					end
					acemenupanel.Serialize( acemenupanel.GearboxData[acemenupanel.CData.UnitsInput.ID].ShiftTable, factor )  --dot intentional
				end

				acemenupanel.CData.WheelPanel = acemenupanel.CData.ShiftGenPanel:Add( "DPanel" )
					acemenupanel.CData.WheelPanel:SetPaintBackground( false )
					acemenupanel.CData.WheelPanel:DockMargin( 4, 0, 4, 0 )
					acemenupanel.CData.WheelPanel:Dock( RIGHT )
					acemenupanel.CData.WheelPanel:SetWide( 76 )
					acemenupanel.CData.WheelPanel:SetTooltip( "If you use default spherical settings, add 0.5 to your wheel diameter.\nFor treaded vehicles, use the diameter of road wheels, not drive wheels." )

					acemenupanel.CData.ShiftGenPanel.WheelLabel = acemenupanel.CData.WheelPanel:Add( "DLabel" )
						acemenupanel.CData.ShiftGenPanel.WheelLabel:Dock( TOP )
						acemenupanel.CData.ShiftGenPanel.WheelLabel:SetDark( true )
						acemenupanel.CData.ShiftGenPanel.WheelLabel:SetText( "Wheel Diameter:" )

					acemenupanel.CData.ShiftGenPanel.Wheel = acemenupanel.CData.WheelPanel:Add( "DNumberWang" )
						acemenupanel.CData.ShiftGenPanel.Wheel:HideWang()
						acemenupanel.CData.ShiftGenPanel.Wheel:SetDrawBorder( false )
						acemenupanel.CData.ShiftGenPanel.Wheel:Dock( BOTTOM )
						acemenupanel.CData.ShiftGenPanel.Wheel:SetDecimals( 2 )
						acemenupanel.CData.ShiftGenPanel.Wheel:SetMinMax( 0, 9999 )
						acemenupanel.CData.ShiftGenPanel.Wheel:SetValue( 30 )

				acemenupanel.CData.RatioPanel = acemenupanel.CData.ShiftGenPanel:Add( "DPanel" )
					acemenupanel.CData.RatioPanel:SetPaintBackground( false )
					acemenupanel.CData.RatioPanel:DockMargin( 4, 0, 4, 0 )
					acemenupanel.CData.RatioPanel:Dock( RIGHT )
					acemenupanel.CData.RatioPanel:SetWide( 76 )
					acemenupanel.CData.RatioPanel:SetTooltip( "Total ratio is the ratio of all gearboxes (excluding this one) multiplied together.\nFor example, if you use engine to automatic to diffs to wheels, your total ratio would be (diff gear ratio * diff final ratio)." )

					acemenupanel.CData.ShiftGenPanel.RatioLabel = acemenupanel.CData.RatioPanel:Add( "DLabel" )
						acemenupanel.CData.ShiftGenPanel.RatioLabel:Dock( TOP )
						acemenupanel.CData.ShiftGenPanel.RatioLabel:SetDark( true )
						acemenupanel.CData.ShiftGenPanel.RatioLabel:SetText( "Total ratio:" )

					acemenupanel.CData.ShiftGenPanel.Ratio = acemenupanel.CData.RatioPanel:Add( "DNumberWang" )
						acemenupanel.CData.ShiftGenPanel.Ratio:HideWang()
						acemenupanel.CData.ShiftGenPanel.Ratio:SetDrawBorder( false )
						acemenupanel.CData.ShiftGenPanel.Ratio:Dock( BOTTOM )
						acemenupanel.CData.ShiftGenPanel.Ratio:SetDecimals( 2 )
						acemenupanel.CData.ShiftGenPanel.Ratio:SetMinMax( 0, 9999 )
						acemenupanel.CData.ShiftGenPanel.Ratio:SetValue( 0.1 )

				acemenupanel.CData.RPMPanel = acemenupanel.CData.ShiftGenPanel:Add( "DPanel" )
					acemenupanel.CData.RPMPanel:SetPaintBackground( false )
					acemenupanel.CData.RPMPanel:DockMargin( 4, 0, 4, 0 )
					acemenupanel.CData.RPMPanel:Dock( RIGHT )
					acemenupanel.CData.RPMPanel:SetWide( 76 )
					acemenupanel.CData.RPMPanel:SetTooltip( "Target engine RPM to upshift at." )

					acemenupanel.CData.ShiftGenPanel.RPMLabel = acemenupanel.CData.RPMPanel:Add( "DLabel" )
						acemenupanel.CData.ShiftGenPanel.RPMLabel:Dock( TOP )
						acemenupanel.CData.ShiftGenPanel.RPMLabel:SetDark( true )
						acemenupanel.CData.ShiftGenPanel.RPMLabel:SetText( "Upshift RPM:" )

					acemenupanel.CData.ShiftGenPanel.RPM = acemenupanel.CData.RPMPanel:Add( "DNumberWang" )
						acemenupanel.CData.ShiftGenPanel.RPM:HideWang()
						acemenupanel.CData.ShiftGenPanel.RPM:SetDrawBorder( false )
						acemenupanel.CData.ShiftGenPanel.RPM:Dock( BOTTOM )
						acemenupanel.CData.ShiftGenPanel.RPM:SetDecimals( 2 )
						acemenupanel.CData.ShiftGenPanel.RPM:SetMinMax( 0, 9999 )
						acemenupanel.CData.ShiftGenPanel.RPM:SetValue( 5000 )

			acemenupanel.CustomDisplay:AddItem(acemenupanel.CData.ShiftGenPanel)
		end
	end

	-- Updates everything that depends on size in place, so the slider survives dragging.
	local function ShowDefinition( Definition, ModelScale )
		acemenupanel:CPanelText("Name", Definition.name, "DermaDefaultBold")
		acemenupanel:CPanelText("MaxTorque", "Clutch Maximum Torque Rating : " .. Definition.maxtq .. "n-m / " .. math.Round(Definition.maxtq * 0.73) .. "ft-lb")
		acemenupanel:CPanelText("Weight", "Weight : " .. Definition.weight .. "kg")
		acemenupanel:CPanelText("SwitchTime", "Shift time : " .. Definition.switch .. "s\n")

		local Preview = acemenupanel.CData.DisplayModel
		if Preview.ACE_Model ~= Definition.model then
			Preview:SetModel( Definition.model )
			Preview.ACE_Model = Definition.model
		end
		if IsValid( Preview.Entity ) then Preview.Entity:SetModelScale( ModelScale, 0 ) end

		maxtorque = Definition.maxtq
	end

	ShowDefinition( Table, Table.ACE_ModelScale or 1 )

	if SizeSlider then
		SizeSlider.OnValueChanged = function( _, Value )
			local Definition, ModelScale, ID = ACE.InterpolateGearboxPreset( Table.id, Value )
			if not Definition then return end

			Size = ACE.GetGearboxSize( Definition )
			RunConsoleCommand( "acemenu_id", ID )
			ShowDefinition( Definition, ModelScale )
		end
	end

	acemenupanel.CustomDisplay:PerformLayout()
end

function ACE_GearsSlider(Gear, Value, ID, Desc, CVT)

	if Gear and not acemenupanel.CData[Gear] then

		acemenupanel.CData[Gear] = vgui.Create( "DNumSlider", acemenupanel.CustomDisplay )
			acemenupanel.CData[Gear]:SetText( Desc or "Gear " .. Gear )
			acemenupanel.CData[Gear].Label:SizeToContents()
			acemenupanel.CData[Gear]:SetDark( true )
			acemenupanel.CData[Gear]:SetMin( CVT and 1 or -2 )
			acemenupanel.CData[Gear]:SetMax( CVT and 20000 or 2 )
			acemenupanel.CData[Gear]:SetDecimals( (not CVT) and 2 or 0 )
			acemenupanel.CData[Gear].Gear = Gear
			acemenupanel.CData[Gear].ID = ID
			acemenupanel.CData[Gear]:SetValue(Value)
			RunConsoleCommand( "acemenu_data" .. Gear, Value )
			acemenupanel.CData[Gear].OnValueChanged = function( slider, val )
				acemenupanel.GearboxData[slider.ID].GearTable[slider.Gear] = val
				RunConsoleCommand( "acemenu_data" .. Gear, val )
			end
		acemenupanel.CustomDisplay:AddItem( acemenupanel.CData[Gear] )
	end

end

function ACE_ShiftPoint(Gear, Value, ID, Desc)
	local Index = Gear + 10
	if Gear and not acemenupanel.CData[Index] then
		acemenupanel.CData[Index] = vgui.Create( "DPanel" )
			acemenupanel.CData[Index]:SetPaintBackground( false )
			acemenupanel.CData[Index]:SetTall( 20 )
			acemenupanel.CData[Index]:SizeToContentsX()

		acemenupanel.CData[Index].Input = acemenupanel.CData[Index]:Add( "DNumberWang" )
			acemenupanel.CData[Index].Input.Gear = Gear
			acemenupanel.CData[Index].Input.ID = ID
			acemenupanel.CData[Index].Input:HideWang()
			acemenupanel.CData[Index].Input:SetDrawBorder( false )
			acemenupanel.CData[Index].Input:SetDecimals( 2 )
			acemenupanel.CData[Index].Input:SetMinMax( 0, 9999 )
			acemenupanel.CData[Index].Input:SetValue( Value )
			acemenupanel.CData[Index].Input:Dock( RIGHT )
			acemenupanel.CData[Index].Input:SetWide( 45 )
			acemenupanel.CData[Index].Input.OnValueChanged = function( box, value )
				acemenupanel.GearboxData[box.ID].ShiftTable[box.Gear] = value
				local _, factor = acemenupanel.CData.UnitsInput:GetSelected()
				acemenupanel.Serialize( acemenupanel.GearboxData[acemenupanel.CData.UnitsInput.ID].ShiftTable, factor )  --dot intentional
			end
			RunConsoleCommand( "acemenu_data9", "10,20,30,40,50,60,70" )

		acemenupanel.CData[Index].Label = acemenupanel.CData[Index]:Add( "DLabel" )
			acemenupanel.CData[Index].Label:Dock( RIGHT )
			acemenupanel.CData[Index].Label:SetWide( 120 )
			acemenupanel.CData[Index].Label:SetDark( true )
			acemenupanel.CData[Index].Label:SetText( Desc )

		acemenupanel.CustomDisplay:AddItem(acemenupanel.CData[Index])
	end
end
