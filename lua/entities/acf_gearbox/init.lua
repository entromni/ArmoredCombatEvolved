AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

local GearboxTable = ACE.Weapons.Gearboxes

do

	local GearboxWireDescs = {
		["Gear"]		= "Sets the gear of this gearbox.",
		["GearUp"]		= "Increases one gear above the current one.",
		["GearDown"]	= "Decreases one gear below the current one.",
		["Clutch"]		= "Applies Clutch to gearbox. Values from 0 to 1.",
		["Brake"]		= "Applies Brake to gearbox. The value you put, the strenght of the brake."
	}

	function ENT:Initialize()

		self.IsGeartrain	= true
		self.Master			= {}
		self.IsMaster		= true

		self.WheelLink		= {} -- a "Link" has these components: Ent, Side, Axis, Rope, RopeLen, Output, ReqTq, Vel

		self.TotalReqTq		= 0
		self.RClutch		= 0
		self.LClutch		= 0
		self.LBrake			= 0
		self.RBrake			= 0
		self.SteerRate		= 0

		self.Gear			= 0
		self.GearRatio		= 0
		self.ChangeFinished = 0

		self.LegalThink		= 0

		self.RPM			= {}
		self.CurRPM			= 0
		self.CVT			= false
		self.DoubleDiff		= false
		self.Auto			= false
		self.InGear			= false
		self.CanUpdate		= true
		self.LastActive		= 0
		self.Legal			= true
		self.Parentable		= false
		self.RootParent		= nil
		self.NextLegalCheck = ACE.CurTime + math.random(ACE.Legal.Min, ACE.Legal.Max) -- give any spawning issues time to iron themselves out
		self.LegalIssues	= ""

		--self.Heat		= ACE.AmbientTemp

	end

	function ACE_MakeGearbox(Owner, Pos, Angle, Id, Data1, Data2, Data3, Data4, Data5, Data6, Data7, Data8, Data9, Data10)

		if not Owner:CheckLimit("_ace_misc") then return false end

		local Gearbox	= ents.Create("acf_gearbox")

		if not IsValid( Gearbox ) then return false end

		if not ACE_CheckGearbox( Id ) then
			Id = "1Gear-T-S" --deal with it
			Data1	= 0.1 --gear1
			Data10  = 0.5 --gear2
		end

		local GearboxData = GearboxTable[Id]

		Gearbox:SetAngles(Angle)
		Gearbox:SetPos(Pos)
		Gearbox:Spawn()

		Gearbox:CPPISetOwner(Owner)
		Gearbox.Id		= Id
		Gearbox.Model	= GearboxData.model
		Gearbox.ACE_ModelScale = GearboxData.ACE_ModelScale or 1
		Gearbox.Mass		= GearboxData.weight		or 1
		Gearbox.SwitchTime  = GearboxData.switch
		Gearbox.MaxTorque	= GearboxData.maxtq		or 0
		Gearbox.Gears	= GearboxData.gears		or 2 --hmmmmmm ok? just if everything fails
		Gearbox.Dual		= GearboxData.doubleclutch	or false
		Gearbox.CVT		= GearboxData.cvt			or false
		Gearbox.DoubleDiff  = GearboxData.doublediff	or false
		Gearbox.Auto		= GearboxData.auto			or false
		Gearbox.Parentable  = GearboxData.parentable	or false
		Gearbox.ACEPoints		= GearboxData.acepoints or 0.9

		if Gearbox.CVT then
			Gearbox.TargetMinRPM = Data3
			Gearbox.TargetMaxRPM = math.max(Data4,Data3 + 100)
			Gearbox.CVTRatio = nil
		end

		Gearbox.GearTable = table.Copy(GearboxData.geartable)
			Gearbox.GearTable.Final = Data10
			Gearbox.GearTable[1] = Data1
			Gearbox.GearTable[2] = Data2
			Gearbox.GearTable[3] = Data3
			Gearbox.GearTable[4] = Data4
			Gearbox.GearTable[5] = Data5
			Gearbox.GearTable[6] = Data6
			Gearbox.GearTable[7] = Data7
			Gearbox.GearTable[8] = Data8
			Gearbox.GearTable[9] = Data9
			Gearbox.GearTable[0] = GearboxData.geartable[0]

			Gearbox.Gear0 = Data10
			Gearbox.Gear1 = Data1
			Gearbox.Gear2 = Data2
			Gearbox.Gear3 = Data3
			Gearbox.Gear4 = Data4
			Gearbox.Gear5 = Data5
			Gearbox.Gear6 = Data6
			Gearbox.Gear7 = Data7
			Gearbox.Gear8 = Data8
			Gearbox.Gear9 = Data9

		Gearbox.GearRatio = (Gearbox.GearTable[0] or 0) * Gearbox.GearTable.Final

		if Gearbox.Auto then
			Gearbox.ShiftPoints = {}
			for part in string.gmatch(Data9, "[^,]+") do Gearbox.ShiftPoints[#Gearbox.ShiftPoints + 1] = tonumber(part) end
			Gearbox.ShiftPoints[0] = -1
			Gearbox.Reverse = Gearbox.Gears + 1
			Gearbox.GearTable[Gearbox.Reverse] = Data8
			Gearbox.Drive = 1
			Gearbox.ShiftScale = 1
		end

		Gearbox:SetModel( Gearbox.Model )

		local Inputs = {"Gear (" .. GearboxWireDescs["Gear"] .. ")","Gear Up (" .. GearboxWireDescs["GearUp"] .. ")","Gear Down (" .. GearboxWireDescs["GearDown"] .. ")"}
		if Gearbox.CVT then
			table.insert(Inputs,"CVT Ratio")
		elseif Gearbox.DoubleDiff then
			table.insert(Inputs, "Steer Rate")
		elseif Gearbox.Auto then
			table.insert(Inputs, "Hold Gear")
			table.insert(Inputs, "Shift Speed Scale")
			Gearbox.Hold = false
		end

		if Gearbox.Dual then
			table.insert(Inputs, "Left Clutch")
			table.insert(Inputs, "Right Clutch")
			table.insert(Inputs, "Left Brake")
			table.insert(Inputs, "Right Brake")
		else
			table.insert(Inputs, "Clutch (" .. GearboxWireDescs["Clutch"] .. ")")
			table.insert(Inputs, "Brake (" .. GearboxWireDescs["Brake"] .. ")")
		end

		local Outputs = { "Ratio", "Entity", "Current Gear" }
		local OutputTypes = { "NORMAL", "ENTITY", "NORMAL" }
		if Gearbox.CVT then
			table.insert(Outputs,"Min Target RPM")
			table.insert(Outputs,"Max Target RPM")
			table.insert(OutputTypes,"NORMAL")
		end

		Gearbox.Inputs = Wire_CreateInputs( Gearbox, Inputs )
		Gearbox.Outputs = WireLib.CreateSpecialOutputs( Gearbox, Outputs, OutputTypes )
		Wire_TriggerOutput(Gearbox, "Entity", Gearbox)

		if Gearbox.CVT then
			Wire_TriggerOutput(Gearbox, "Min Target RPM", Gearbox.TargetMinRPM)
			Wire_TriggerOutput(Gearbox, "Max Target RPM", Gearbox.TargetMaxRPM)
		end

		Gearbox.LClutch = Gearbox.MaxTorque
		Gearbox.RClutch = Gearbox.MaxTorque

		local Scale = Gearbox.ACE_ModelScale

		if Scale == 1 then
			Gearbox:PhysicsInit( SOLID_VPHYSICS )
			Gearbox:SetMoveType( MOVETYPE_VPHYSICS )
			Gearbox:SetSolid( SOLID_VPHYSICS )
		elseif not Gearbox:ACE_ApplyScaledCollision( Scale ) then
			Gearbox:Remove()
			return false
		end

		-- The client builds the matching collision and visuals from this.
		Gearbox:SetNWFloat( "ACE_ModelScale", Scale )

		local phys = Gearbox:GetPhysicsObject()
		if IsValid( phys ) then
			phys:SetMass( Gearbox.Mass )
			Gearbox.ModelInertia = 0.99 * phys:GetInertia() / phys:GetMass() -- giving a little wiggle room
		end

		-- Attachments come from the unscaled model, so scale their local positions.
		Gearbox.In = Gearbox:WorldToLocal(Gearbox:GetAttachment(Gearbox:LookupAttachment( "input" )).Pos) * Scale
		Gearbox.OutL = Gearbox:WorldToLocal(Gearbox:GetAttachment(Gearbox:LookupAttachment( "driveshaftL" )).Pos) * Scale
		Gearbox.OutR = Gearbox:WorldToLocal(Gearbox:GetAttachment(Gearbox:LookupAttachment( "driveshaftR" )).Pos) * Scale

		Owner:AddCount("_ace_misc", Gearbox)
		Owner:AddCleanup( "acemenu", Gearbox )

		Gearbox:ChangeGear(1)

		if Gearbox.Dual or Gearbox.DoubleDiff then
			Gearbox:SetBodygroup(1, 1)
		else
			Gearbox:SetBodygroup(1, 0)
		end

		Gearbox:SetNWString( "WireName", GearboxData.name )
		Gearbox:UpdateOverlayText()

		ACE_Activate( Gearbox, 0 )

		return Gearbox
	end
	list.Set( "ACFCvars", "acf_gearbox", {"id", "data1", "data2", "data3", "data4", "data5", "data6", "data7", "data8", "data9", "data10", "data11", "data12", "data13", "data14", "data15"} )
	duplicator.RegisterEntityClass("acf_gearbox", ACE_MakeGearbox, "Pos", "Angle", "Id", "Gear1", "Gear2", "Gear3", "Gear4", "Gear5", "Gear6", "Gear7", "Gear8", "Gear9", "Gear0" )

end

function ENT:Update( ArgsTable )
	-- That table is the player data, as sorted in the ACFCvars above, with player who shot,
	-- and pos and angle of the tool trace inserted at the start

	local Id = ArgsTable[4] -- Argtable[4] is the engine ID
	local GearboxData = GearboxTable[Id]
	if not GearboxData then
		return false, "Invalid gearbox selection!"
	end

	-- Procedural sizes can switch between stock anchor models (e.g. small to
	-- medium) while remaining the same gearbox subtype. Validate category and
	-- subtype instead of requiring the model path to remain identical.
	local PreviousData = GearboxTable[self.Id]
	local SameSubtype = PreviousData
		and PreviousData.category == GearboxData.category
		and ACE.GetGearboxSubtype(PreviousData) == ACE.GetGearboxSubtype(GearboxData)

	if not SameSubtype and GearboxData.model ~= self.Model then
		return false, "The new gearbox must have the same model or gearbox type/subtype!"
	end

	-- Rebuilding Wire ports disconnects Wire links. A size-anchor ID change
	-- does not change the port layout when the gearbox subtype is unchanged.
	local WireConfigChanged = self.CVT ~= (GearboxData.cvt or false)
		or self.DoubleDiff ~= (GearboxData.doublediff or false)
		or self.Auto ~= (GearboxData.auto or false)
		or self.Dual ~= (GearboxData.doubleclutch or false)

	if self.Id ~= Id then

		self.Id		= Id
		self.Mass	= GearboxData.weight		or 1
		self.SwitchTime = GearboxData.switch
		self.MaxTorque  = GearboxData.maxtq		or 0
		self.Gears	= GearboxData.gears		or 2
		self.Dual	= GearboxData.doubleclutch	or false
		self.CVT		= GearboxData.cvt			or false
		self.DoubleDiff = GearboxData.doublediff	or false
		self.Auto	= GearboxData.auto			or false
		self.Parentable = GearboxData.parentable	or false

		if WireConfigChanged then
		local Inputs = {"Gear","Gear Up","Gear Down"}
			if self.CVT then
				table.insert(Inputs,"CVT Ratio")
			elseif self.DoubleDiff then
				table.insert(Inputs, "Steer Rate")
			elseif self.Auto then
				table.insert(Inputs, "Hold Gear")
				table.insert(Inputs, "Shift Speed Scale")
				if WireConfigChanged then self.Hold = false end
			end
	
			if self.Dual then
				table.insert(Inputs, "Left Clutch")
				table.insert(Inputs, "Right Clutch")
				table.insert(Inputs, "Left Brake")
				table.insert(Inputs, "Right Brake")
			else
				table.insert(Inputs, "Clutch")
				table.insert(Inputs, "Brake")
			end
	
			local Outputs = { "Ratio", "Entity", "Current Gear" }
			local OutputTypes = { "NORMAL", "ENTITY", "NORMAL" }
			if self.CVT then
				table.insert(Outputs,"Min Target RPM")
				table.insert(Outputs,"Max Target RPM")
				table.insert(OutputTypes,"NORMAL")
			end
	
			local phys = self:GetPhysicsObject()
			if IsValid( phys ) then
				phys:SetMass( self.Mass )
			end
	
			self.Inputs = Wire_CreateInputs( self, Inputs )
			self.Outputs = WireLib.CreateSpecialOutputs( self, Outputs, OutputTypes )
			Wire_TriggerOutput( self, "Entity", self )
		end
	end

	-- Refresh the selected gearbox's weight even when its ID is unchanged.
	self.Mass = GearboxData.weight or self.Mass or 1

	-- A size change may cross an anchor boundary, changing the underlying
	-- stock model (small/medium/large). Rebuild whenever either model or scale
	-- changes, not only when the numeric scale changes.
	local NewModel = GearboxData.model
	local NewScale = GearboxData.ACE_ModelScale or 1

	-- Migrate entities saved before procedural scaling added these fields.
	-- Their actual model is authoritative; missing scale means stock scale.
	-- The entity's actual model is authoritative. `self.Model` is only a
	-- cached gearbox-definition field and may be stale on older live entities.
	-- Treat a stale cache as a migration too, so attachment/physics state is
	-- rebuilt instead of silently trusting old cached In/Out vectors.
	local CurrentModel = self:GetModel()
	local LegacyScaleMissing = self.ACE_ModelScale == nil
	local ModelChanged = NewModel ~= CurrentModel or self.Model ~= NewModel
	local ScaleChanged = NewScale ~= (self.ACE_ModelScale or 1) or LegacyScaleMissing

	if ModelChanged or ScaleChanged then
		local OldModel = CurrentModel
		local OldScale = self.ACE_ModelScale or self:GetNWFloat("ACE_ModelScale", 1)
		-- NWFloat can be zero on legacy entities before the networked value is
		-- initialized. Recover their actual scale from the saved gearbox ID;
		-- otherwise the attachment scale ratio becomes nil and valid cached
		-- In/Out vectors are discarded, causing the false attachment failure.
		if not isnumber(OldScale) or OldScale <= 0 then
			local PreviousData = GearboxTable[self.Id]
			OldScale = PreviousData and PreviousData.ACE_ModelScale or 1
		end
		local OldIn, OldOutL, OldOutR = self.In, self.OutL, self.OutR
		local HasParent = IsValid(self:GetParent())
		local SavedPos, SavedAng = self:GetPos(), self:GetAngles()
		local OldPhys = self:GetPhysicsObject()
		local SavedVelocity = IsValid(OldPhys) and OldPhys:GetVelocity() or vector_origin
		local SavedAngleVelocity = IsValid(OldPhys) and OldPhys:GetAngleVelocity() or vector_origin
		local SavedMotion = not IsValid(OldPhys) or OldPhys:IsMotionEnabled()
		local SavedAsleep = IsValid(OldPhys) and OldPhys:IsAsleep()

		-- Do not detach/reparent a physics gearbox during resize. SetParent()
		-- computes a new local origin from the parent transform; on old dupe
		-- assemblies that transform can be far outside the valid local-origin
		-- range (the repeated Bad SetLocalOrigin Z value). PhysicsInit can
		-- rebuild the collision in place without changing the parent relation.
		local function RestoreTransformAndPhysics()
			-- Only restore the entity transform when it is not parented. For a
			-- parented entity, GetPos/SetPos semantics during physics rebuild
			-- can mix parent-local and world coordinates and recreate the error.
			if not HasParent then
				self:SetPos(SavedPos)
				self:SetAngles(SavedAng)
			end

			local Phys = self:GetPhysicsObject()
			if not IsValid(Phys) then return end

			Phys:SetMass(self.Mass)
			Phys:EnableMotion(SavedMotion)
			Phys:SetVelocity(SavedVelocity)
			Phys:SetAngleVelocity(SavedAngleVelocity)

			if SavedAsleep then
				Phys:Sleep()
			else
				Phys:Wake()
			end
		end

		-- Read attachment offsets on a temporary model at the world origin.
		-- GetAttachment returns world coordinates; on entities far from the
		-- origin, a stale attachment matrix can resolve to (0, 0, 0), which
		-- then looks like an invalid enormous local offset. A temporary model
		-- near the origin avoids depending on the resized entity's transform.
		local function ReadModelAttachments(Model, Scale)
			local Probe = ents.Create("prop_dynamic")
			if not IsValid(Probe) then return {} end

			Probe:SetModel(Model)
			Probe:SetPos(vector_origin)
			Probe:SetAngles(angle_zero)
			Probe:SetNoDraw(true)
			Probe:SetNotSolid(true)
			Probe:Spawn()
			Probe:Activate()

			local function ReadAttachment(Name)
				local AttachmentID = Probe:LookupAttachment(Name)
				if not AttachmentID or AttachmentID <= 0 then return nil end

				local Attachment = Probe:GetAttachment(AttachmentID)
				if not Attachment or not isvector(Attachment.Pos) then return nil end

				local LocalPos = Attachment.Pos - Probe:GetPos()
				LocalPos:Rotate(-Probe:GetAngles())

				local Mins, Maxs = Probe:GetModelBounds()
				local Radius = math.max(Mins:Length(), Maxs:Length()) + 32
				if not isvector(LocalPos) or LocalPos:Length() > Radius then return nil end

				return LocalPos * Scale
			end

			local Attachments = {
				In = ReadAttachment("input"),
				OutL = ReadAttachment("driveshaftL"),
				OutR = ReadAttachment("driveshaftR"),
			}

			Probe:Remove()
			return Attachments
		end
		local function BuildCollision(Model, Scale)
			self:SetModel(Model)
			local Attachments = ReadModelAttachments(Model, Scale)

			local Success
			if Scale == 1 then
				self:PhysicsInit(SOLID_VPHYSICS)
				self:SetMoveType(MOVETYPE_VPHYSICS)
				self:SetSolid(SOLID_VPHYSICS)
				self:EnableCustomCollisions(false)
				Success = IsValid(self:GetPhysicsObject())
			else
				Success = self:ACE_ApplyScaledCollision(Scale)
			end

			return Success, Attachments
		end

		local function RollbackResize()
			BuildCollision(OldModel, OldScale)
			RestoreTransformAndPhysics()
			self.Model = OldModel
			self.ACE_ModelScale = OldScale
			self:SetNWFloat("ACE_ModelScale", OldScale)
			self.In, self.OutL, self.OutR = OldIn, OldOutL, OldOutR
		end

		local CollisionBuilt, ModelAttachments = BuildCollision(NewModel, NewScale)
		if not CollisionBuilt then
			RollbackResize()
			return false, "Failed to rebuild gearbox collision for the selected size/model!"
		end

		RestoreTransformAndPhysics()

		-- Keep cached offsets for the same model; for an anchor/model change,
		-- use the offsets captured after SetModel but before PhysicsInit.
		local AttachmentScale = OldScale > 0 and NewScale / OldScale or nil
		local NewIn, NewOutL, NewOutR

		if NewModel == CurrentModel and AttachmentScale then
			NewIn = isvector(OldIn) and OldIn * AttachmentScale or nil
			NewOutL = isvector(OldOutL) and OldOutL * AttachmentScale or nil
			NewOutR = isvector(OldOutR) and OldOutR * AttachmentScale or nil
		end

		NewIn = NewIn or ModelAttachments.In
		NewOutL = NewOutL or ModelAttachments.OutL
		NewOutR = NewOutR or ModelAttachments.OutR

		if not isvector(NewIn) or not isvector(NewOutL) or not isvector(NewOutR) then
			RollbackResize()
			return false, "Gearbox resize failed: model attachments were invalid after rebuilding physics; the previous model/size was restored."
		end

		self.Model = NewModel
		self.ACE_ModelScale = NewScale
		self:SetNWFloat("ACE_ModelScale", NewScale)
		self.In, self.OutL, self.OutR = NewIn, NewOutL, NewOutR

		-- PhysicsInit replaces the gearbox PhysObj. Recreating keyframe ropes
		-- synchronously in the same update can bind their endpoints while the
		-- entity/physics transforms are still transitioning; the ropes then
		-- resolve one or both attachments to world origin. Remove the old
		-- visuals now, and recreate them on the next timer tick.
		self.ACE_LinkRefreshPending = true
		self.ACE_LinkRefreshToken = (self.ACE_LinkRefreshToken or 0) + 1
		local RefreshToken = self.ACE_LinkRefreshToken

		for _, Source in ipairs(ents.FindByClass("acf_gearbox")) do
			for _, Link in pairs(Source.WheelLink or {}) do
				if Source ~= self and Link.Ent ~= self then continue end

				if IsValid(Link.Rope) then Link.Rope:Remove() end
				Link.Rope = nil

				for _, Data in pairs(constraint.FindConstraints(Source, "Rope") or {}) do
					if (Data.Ent1 == Source and Data.Ent2 == Link.Ent)
					or (Data.Ent1 == Link.Ent and Data.Ent2 == Source) then
						if IsValid(Data.Constraint) then Data.Constraint:Remove() end
					end
				end
			end
		end

		timer.Simple(0, function()
			if not IsValid(self) or self.ACE_LinkRefreshToken ~= RefreshToken then return end

			for _, Source in ipairs(ents.FindByClass("acf_gearbox")) do
				for _, Link in pairs(Source.WheelLink or {}) do
					local Target = Link.Ent
					if not IsValid(Target) then continue end
					if Source ~= self and Target ~= self then continue end

					local In = Target.IsGeartrain and Target.In or vector_origin
					local InWorld = Target:LocalToWorld(In)
					local Out = Link.Output

					if Source == self then
						local Side = Source:WorldToLocal(InWorld).y < 0 and 0 or 1
					Link.Side = Side
					Out = Side == 0 and self.OutL or self.OutR
					Link.Output = Out
				end

					if not isvector(Out) then continue end

					local OutWorld = Source:LocalToWorld(Out)
					Link.RopeLen = OutWorld:Distance(InWorld)

					if Target == self then
						local Phys = Target:GetPhysicsObject()
					if IsValid(Phys) then
						local Axis = Phys:WorldToLocalVector(Source:GetRight())
					Link.Axis = Axis
					Link.Inertia = (Axis * Phys:GetInertia()):Length()
					end
					end

					local Owner = Source:CPPIGetOwner()
					local MakeRopes = IsValid(Owner)
						and Owner:GetInfoNum("ace_mobility_rope_links", 1) == 1

					if MakeRopes then
						Link.Rope = ACE_CreateLinkRope(OutWorld, Source, Out, Target, In)
					end
				end
			end

			self.ACE_LinkRefreshPending = false
		end)
	end
	-- Weight can change even if the selected size resolves to the same model
	-- scale, so refresh mass/inertia on every update.
	local Phys = self:GetPhysicsObject()
	if IsValid(Phys) then
		Phys:SetMass(self.Mass)
		self.ModelInertia = 0.99 * Phys:GetInertia() / Phys:GetMass()
	end

	if self.CVT then
		self.TargetMinRPM = ArgsTable[7]
		self.TargetMaxRPM = math.max(ArgsTable[8],ArgsTable[7] + 100)
		self.CVTRatio = nil
		Wire_TriggerOutput(self, "Min Target RPM", self.TargetMinRPM)
		Wire_TriggerOutput(self, "Max Target RPM", self.TargetMaxRPM)
	end

	self.GearTable.Final = ArgsTable[14]
	self.GearTable[1] = ArgsTable[5]
	self.GearTable[2] = ArgsTable[6]
	self.GearTable[3] = ArgsTable[7]
	self.GearTable[4] = ArgsTable[8]
	self.GearTable[5] = ArgsTable[9]
	self.GearTable[6] = ArgsTable[10]
	self.GearTable[7] = ArgsTable[11]
	self.GearTable[8] = ArgsTable[12]
	self.GearTable[9] = ArgsTable[13]
	self.GearTable[0] = GearboxData.geartable[0]

	self.Gear0 = ArgsTable[14]
	self.Gear1 = ArgsTable[5]
	self.Gear2 = ArgsTable[6]
	self.Gear3 = ArgsTable[7]
	self.Gear4 = ArgsTable[8]
	self.Gear5 = ArgsTable[9]
	self.Gear6 = ArgsTable[10]
	self.Gear7 = ArgsTable[11]
	self.Gear8 = ArgsTable[12]
	self.Gear9 = ArgsTable[13]

	self.GearRatio = (self.GearTable[0] or 0) * self.GearTable.Final

	if self.Auto then
		self.ShiftPoints = {}
		for part in string.gmatch(ArgsTable[13], "[^,]+") do self.ShiftPoints[#self.ShiftPoints + 1] = tonumber(part) end
		self.ShiftPoints[0] = -1
		self.Reverse = self.Gears + 1
		self.GearTable[self.Reverse] = ArgsTable[12]
		self.Drive = 1
		self.ShiftScale = 1
	end

	--self:ChangeGear(1) -- fails on updating because func exits on detecting same gear
	self.Gear = 1
	self.GearRatio = (self.GearTable[self.Gear] or 0) * self.GearTable.Final
	self.ChangeFinished = CurTime() + self.SwitchTime
	self.InGear = false

	if self.Dual or self.DoubleDiff then
		self:SetBodygroup(1, 1)
	else
		self:SetBodygroup(1, 0)
	end

	self:SetNWString( "WireName", GearboxData.name )
	self:UpdateOverlayText()

	ACE_Activate( self, 1 )

	return true, "Gearbox updated successfully!"
end

function ENT:UpdateOverlayText()

	local text = ""

	if self.CVT then
		text = "Reverse Gear: " .. math.Round( self.GearTable[ 2 ], 2 ) -- maybe a better name than "gear 2"...?
		text = text .. "\nTarget: " .. math.Round( self.TargetMinRPM ) .. " - " .. math.Round( self.TargetMaxRPM ) .. " RPM\n"
	elseif self.Auto then
		for i = 1, self.Gears do
			text = text .. "Gear " .. i .. ": " .. math.Round( self.GearTable[ i ], 2 ) .. ", Upshift @ " .. math.Round( self.ShiftPoints[i] / 10.936, 1 ) .. " kph / " .. math.Round( self.ShiftPoints[i] / 17.6 ,1 ) .. " mph\n"
		end
	else
		for i = 1, self.Gears do
			text = text .. "Gear " .. i .. ": " .. math.Round( self.GearTable[ i ], 2 ) .. "\n"
		end
	end
	if self.Auto then
		text = text .. "Reverse gear: " .. math.Round( self.GearTable[ self.Reverse ], 2 ) .. "\n"
	end

	text = text .. "Final Drive: " .. math.Round( self.Gear0, 2 ) .. "\n"
	text = text .. "Torque Rating: " .. self.MaxTorque .. " Nm / " .. math.Round( self.MaxTorque * 0.73 ) .. " ft-lb"

	if not self.Legal then
		text = text .. "\nNot legal, disabled for " .. math.ceil(self.NextLegalCheck - ACE.CurTime) .. "s\nIssues: " .. self.LegalIssues
	end

	self:SetOverlayText( text )

end


--- Called by the ACE tool after Entity:Activate() (the name is shared with acf_gun).
-- Reapplies mass and inertia on custom size gearboxes.
-- @return boolean True if the gearbox has a valid physics object.
function ENT:ACE_FinalizeCustomCaliberPhysics()
	local phys = self:GetPhysicsObject()
	if not IsValid( phys ) then return false end
	if self.ACE_ModelScale == 1 then return true end

	phys:SetMass( self.Mass )
	self.ModelInertia = 0.99 * phys:GetInertia() / phys:GetMass()

	return true
end

-- prevent people from changing bodygroup
function ENT:CanProperty( _, property )

	return property ~= "bodygroups"

end

function ENT:TriggerInput( iname, value )

	if ( iname == "Gear" ) then
		if self.Auto then
			self:ChangeDrive(value)
		else
			self:ChangeGear(value)
		end
	elseif ( iname == "Gear Up" ) and value ~= 0 then
		if self.Auto then
			self:ChangeDrive(self.Drive + 1)
		else
			self:ChangeGear(self.Gear + 1)
		end
	elseif ( iname == "Gear Down" ) and value ~= 0 then
		if self.Auto then
			self:ChangeDrive(self.Drive - 1)
		else
			self:ChangeGear(self.Gear - 1)
		end
	elseif ( iname == "Clutch" ) then
		self.LClutch = math.Clamp(1-value,0,1) * self.MaxTorque
		self.RClutch = math.Clamp(1-value,0,1) * self.MaxTorque
	elseif ( iname == "Brake" ) then
		self.LBrake = math.Clamp(value,0,100)
		self.RBrake = math.Clamp(value,0,100)
	elseif ( iname == "Left Brake" ) then
		self.LBrake = math.Clamp(value,0,100)
	elseif ( iname == "Right Brake" ) then
		self.RBrake = math.Clamp(value,0,100)
	elseif ( iname == "Left Clutch" ) then
		self.LClutch = math.Clamp(1-value,0,1) * self.MaxTorque
	elseif ( iname == "Right Clutch" ) then
		self.RClutch = math.Clamp(1-value,0,1) * self.MaxTorque
	elseif ( iname == "CVT Ratio" ) then
		self.CVTRatio = math.Clamp(value,0,1)
	elseif ( iname == "Steer Rate" ) then
		self.SteerRate = math.Clamp(value,-1,1)
	elseif ( iname == "Hold Gear" ) then
		self.Hold = value ~= 0
	elseif ( iname == "Shift Speed Scale" ) then
		self.ShiftScale = math.Clamp(value,0.1,1.5)
	end

end

function ENT:Think()

	if ACE.CurTime > self.NextLegalCheck then
		self.Legal, self.LegalIssues = ACE_CheckLegal(self, self.Model, math.Round(self.Mass,2), self.ModelInertia, true, true) -- requiresweld overrides parentable, need to set it false for parent-only gearboxes
		self.NextLegalCheck = ACE.Legal.NextCheck(self.legal)
		self:UpdateOverlayText()

		if self.Legal and self.Parentable then self.RootParent = ACE_GetPhysicalParent(self) end
	end

	local Time = CurTime()

	if self.LastActive + 2 > Time then
		self:CheckRopes()
	end

	self:NextThink( Time + math.random( 5, 10 ) )
	return true

end

function ENT:CheckRopes()

	if self.ACE_LinkRefreshPending then return end

	for _, Link in pairs( self.WheelLink ) do

		local Ent = Link.Ent

		--skips any invalid entity and remove from list
		if not IsValid(Ent) then continue end
		if Ent.ACE_LinkRefreshPending then continue end

		local OutPos = self:LocalToWorld( Link.Output )
		local InPos = Ent:GetPos()
		if Ent.IsGeartrain then
			InPos = Ent:LocalToWorld( Ent.In )
		end

		-- make sure it is not stretched too far
		if OutPos:Distance( InPos ) > Link.RopeLen * 1.5 then
			self:Unlink( Ent )
			local soundstr =  "physics/metal/metal_box_impact_bullet" .. tostring(math.random(1, 3)) .. ".wav"
			self:EmitSound(soundstr,500,100)
		end

		-- make sure the angle is not excessive
		if not self:Checkdriveshaft( Ent ) then
			self:Unlink( Ent )
			local soundstr =  "physics/metal/metal_box_impact_bullet" .. tostring(math.random(1, 3)) .. ".wav"
			self:EmitSound(soundstr,500,100)
		end
	end
end

-- Check if every entity we are linked to still actually exists
-- and remove any links that are invalid.
function ENT:CheckEnts()

	for Key, Link in pairs( self.WheelLink ) do

		if not IsValid( Link.Ent ) then
			table.remove( self.WheelLink, Key )
		continue end

		local Phys = Link.Ent:GetPhysicsObject()
		if not IsValid( Phys ) then
			Link.Ent:Remove()
			table.remove( self.WheelLink, Key )
		end

	end

end

function ENT:Calc( InputRPM, InputInertia )

	if not self.Legal then return 0 end

	if self.LastActive == CurTime() then
		return math.min( self.TotalReqTq, self.MaxTorque )
	end

	if self.ChangeFinished < CurTime() then
		self.InGear = true
	end

	self:CheckEnts()

	local BoxPhys = self:GetPhysicsObject()
	local SelfWorld = BoxPhys:LocalToWorldVector( BoxPhys:GetAngleVelocity() )

	if self.CVT and self.Gear == 1 then
		if self.CVTRatio and self.CVTRatio > 0 then
			self.GearTable[1] = math.Clamp(self.CVTRatio,0.01,1)
		else
			self.GearTable[1] = math.Clamp((InputRPM - self.TargetMinRPM) / ((self.TargetMaxRPM - self.TargetMinRPM) or 1),0.05,1)
		end
		self.GearRatio = (self.GearTable[1] or 0) * self.GearTable.Final
		Wire_TriggerOutput(self, "Ratio", self.GearRatio)
	end

	if self.Auto and self.Drive == 1 and self.InGear then
		local Base = ACE_GetPhysicalParent( self )
		local PhysObj = Base:GetPhysicsObject()
		local vel = PhysObj:GetVelocity():Length()
		if vel > (self.ShiftPoints[self.Gear] * self.ShiftScale) and not (self.Gear == self.Gears) and not self.Hold then
			self:ChangeGear(self.Gear + 1)
		elseif vel < (self.ShiftPoints[self.Gear-1] * self.ShiftScale) then
			self:ChangeGear(self.Gear - 1)
		end
	end

	self.TotalReqTq = 0

	for Key, Link in pairs( self.WheelLink ) do

		if not IsValid( Link.Ent ) then table.remove( self.WheelLink, Key ) continue end
		if Link.Notvalid then continue end

		local Clutch = 0
		if Link.Side == 0 then
			Clutch = self.LClutch
		elseif Link.Side == 1 then
			Clutch = self.RClutch
		end

		Link.ReqTq = 0
		if Link.Ent.IsGeartrain then
			if not Link.Ent.Legal then continue end
			local Inertia = 0
			if self.GearRatio ~= 0 then Inertia = InputInertia / self.GearRatio end
			Link.ReqTq = math.min( Clutch, math.abs( Link.Ent:Calc( InputRPM * self.GearRatio, Inertia ) * self.GearRatio ) )
		elseif self.DoubleDiff then
			local RPM = self:CalcWheel( Link, SelfWorld )
			if self.GearRatio ~= 0 and ( ( InputRPM > 0 and RPM < InputRPM ) or ( InputRPM < 0 and RPM > InputRPM ) ) then
				local NTq = math.min( Clutch, ( InputRPM - RPM) * InputInertia)

				if self.SteerRate ~= 0 then
					Sign = self.SteerRate / math.abs( self.SteerRate )
				else
					Sign = 0
				end
				if Link.Side == 0 then
						local DTq = math.Clamp( ( self.SteerRate * ( ( InputRPM * ( math.abs( self.SteerRate ) + 1 ) ) - (RPM * Sign) ) ) * InputInertia, -self.MaxTorque, self.MaxTorque )
					Link.ReqTq = ( NTq + DTq )
				elseif Link.Side == 1 then
						local DTq = math.Clamp( ( self.SteerRate * ( ( InputRPM * ( math.abs( self.SteerRate ) + 1 ) ) + (RPM * Sign) ) ) * InputInertia, -self.MaxTorque, self.MaxTorque )
					Link.ReqTq = ( NTq - DTq )
				end
			end
		else
			local RPM = self:CalcWheel( Link, SelfWorld )
			if self.GearRatio ~= 0 and ( ( InputRPM > 0 and RPM < InputRPM ) or ( InputRPM < 0 and RPM > InputRPM ) ) then
				Link.ReqTq = math.min( Clutch, ( InputRPM - RPM ) * InputInertia )
			end
		end
		self.TotalReqTq = self.TotalReqTq + math.abs( Link.ReqTq )


	end

	--I would need to learn more about this, disabled atm
	--self.Heat = ACE_HeatFromGearbox( self , InputRPM)
	--Wire_TriggerOutput(self, "Heat", self.Heat)

	return math.min( self.TotalReqTq, self.MaxTorque )

end

function ENT:CalcWheel( Link, SelfWorld )

	local Wheel = Link.Ent
	local WheelPhys = Wheel:GetPhysicsObject()
	local VelDiff = WheelPhys:LocalToWorldVector( WheelPhys:GetAngleVelocity() ) - SelfWorld
	local BaseRPM = VelDiff:Dot( WheelPhys:LocalToWorldVector( Link.Axis ) )
	Link.Vel = BaseRPM

	if self.GearRatio == 0 then return 0 end

	-- Reported BaseRPM is in angle per second and in the wrong direction, so we convert and add the gearratio
	return BaseRPM / self.GearRatio / -6

end

function ENT:Act( Torque, DeltaTime, MassRatio )

	if not self.Legal then self.LastActive = CurTime() return end
	--internal torque loss from being damaged
	local Loss = math.Clamp(((1 - 0.4) / 0.5) * ((self.ACF.Health / self.ACF.MaxHealth) - 1) + 1, 0.4, 1)

	--internal torque loss from inefficiency
	local Slop = self.Auto and 0.9 or 1

	local ReactTq = 0
	-- Calculate the ratio of total requested torque versus what's avaliable, and then multiply it but the current gearratio
	local AvailTq = 0
	if Torque ~= 0 and self.GearRatio ~= 0 then
		AvailTq = math.min( math.abs( Torque ) / self.TotalReqTq, 1 ) / self.GearRatio * -( -Torque / math.abs( Torque ) ) * Loss * Slop
	end

	for _, Link in pairs( self.WheelLink ) do

		if Link.Notvalid then continue end

		local Brake = 0
		if Link.Side == 0 then
			Brake = self.LBrake
		elseif Link.Side == 1 then
			Brake = self.RBrake
		end

		if Link.Ent.IsGeartrain then
			Link.Ent:Act( Link.ReqTq * AvailTq, DeltaTime, MassRatio )
		else
			self:ActWheel( Link, Link.ReqTq * AvailTq, Brake, DeltaTime )
			ReactTq = ReactTq + Link.ReqTq * AvailTq
		end


	end

	local BoxPhys
	if IsValid( self.RootParent ) then
		BoxPhys = self.RootParent:GetPhysicsObject()
	else
		BoxPhys = self:GetPhysicsObject()
	end

	if IsValid( BoxPhys ) and ReactTq ~= 0 then
		local Torque = self:GetRight() * math.Clamp( 2 * math.deg( ReactTq * MassRatio ) * DeltaTime, -500000, 500000 )
		BoxPhys:ApplyTorqueCenter( Torque )
	end

	self.LastActive = CurTime()

end

function ENT:ActWheel( Link, Torque, Brake, DeltaTime )

	local Phys = Link.Ent:GetPhysicsObject()
	local TorqueAxis = Phys:LocalToWorldVector( Link.Axis )

	local BrakeMult = 0
	if Brake > 0 then
		BrakeMult = Link.Vel * Link.Inertia * Brake / 5
	end
	local Torque = TorqueAxis * math.Clamp( math.deg( -Torque - BrakeMult ) * DeltaTime, -500000, 500000 )
	Phys:ApplyTorqueCenter( Torque )
end

function ENT:ChangeGear(value)

	local new = math.Clamp(math.floor(value),0,self.Gears)
	if self.Gear == new then return end

	self.Gear = new
	self.GearRatio = (self.GearTable[self.Gear] or 0) * self.GearTable.Final
	self.ChangeFinished = CurTime() + self.SwitchTime
	self.InGear = false

	Wire_TriggerOutput(self, "Current Gear", self.Gear)
	self:EmitSound("buttons/lever7.wav",250,100)
	Wire_TriggerOutput(self, "Ratio", self.GearRatio)

end

--handles gearing for automatics; 0=neutral, 1=forward autogearing, 2=reverse
function ENT:ChangeDrive(value)

	local new = math.Clamp(math.floor(value),0,2)
	if self.Drive == new then return end

	self.Drive = new
	if self.Drive == 2 then
		self.Gear = self.Reverse
		self.GearRatio = (self.GearTable[self.Gear] or 0) * self.GearTable.Final
		self.ChangeFinished = CurTime() + self.SwitchTime
		self.InGear = false

		Wire_TriggerOutput(self, "Current Gear", self.Gear)
		self:EmitSound("buttons/lever7.wav",250,100)
		Wire_TriggerOutput(self, "Ratio", self.GearRatio)
	else
		self:ChangeGear(self.Drive) --autogearing in :calc will set correct gear
	end

end

do

	--[[
	--HARDCODED. USE MODELDEFINITION INSTEAD
	local TransAxialGearboxes = {
		["models/engines/transaxial_l.mdl"] = true,
		["models/engines/transaxial_m.mdl"] = true,
		["models/engines/transaxial_s.mdl"] = true,
		["models/engines/transaxial_t.mdl"] = true --mhm acf extras invading...
	}
	]]

	function ENT:Checkdriveshaft( NextEnt )

		local InPos = vector_origin
		if NextEnt.IsGeartrain then
			InPos = NextEnt.In
		end
		local InPosWorld = NextEnt:LocalToWorld( InPos )

		local OutPos	= self.OutR
		if self:WorldToLocal( InPosWorld ).y < 0 then
			OutPos  = self.OutL
		end
		local OutPosWorld = self:LocalToWorld( OutPos )

		local MaxAngle = 0.7 --magic number to define the max tolerance of link between gearboxes
		local Direction = ( self:GetRight() * OutPos.y ):GetNormalized()
		local DrvAngle = ( OutPosWorld - InPosWorld ):GetNormalized():Dot( Direction )

		if DrvAngle < MaxAngle then
			return false
		--else
			--[[ --Disabled since this could break several builds. When we have more junctions, this could be enforced.
			--Now, do the same, but from gearbox's point this time.
			Direction 	= TransAxialGearboxes[ NextEnt:GetModel() ] and -NextEnt:GetForward() or -NextEnt:GetRight() --transaxial like those T junctions. Forward is for Straight like gearboxes.
			DrvAngle 	= ( InPosWorld - OutPosWorld ):GetNormalized():Dot( Direction )

			if DrvAngle < MaxAngle then
				return false
			end
			]]
		end

		return true
	end

end

function ENT:Link( Target )

	if self.ACE_LinkRefreshPending or (IsValid(Target) and Target.ACE_LinkRefreshPending) then
		return false, "Gearbox attachments are refreshing after a size update; try linking again in a moment!"
	end

	if not IsValid( Target ) or not table.HasValue( { "prop_physics", "acf_gearbox", "tire" }, Target:GetClass() ) then
		return false, "Can only link props or gearboxes!"
	end

	-- Check if target is already linked
	for _, Link in pairs( self.WheelLink ) do
		if Link.Ent == Target then
			return false, "That is already linked to this gearbox!"
		end
	end

	-- make sure the angle is not excessive
	if not self:Checkdriveshaft( Target ) then
		return false, "Cannot link due to excessive driveshaft angle!"
	end

	local InPos = Vector( 0, 0, 0 )
	if Target.IsGeartrain then
		InPos = Target.In
	end
	local InPosWorld = Target:LocalToWorld( InPos )

	local OutPos	= self.OutR
	local Side	= 1
	if self:WorldToLocal( InPosWorld ).y < 0 then
		OutPos  = self.OutL
		Side	= 0
	end
	local OutPosWorld = self:LocalToWorld( OutPos )

	local Rope = nil
	if self:CPPIGetOwner():GetInfoNum( "ace_mobility_rope_links", 1) == 1 then
		Rope = ACE_CreateLinkRope( OutPosWorld, self, OutPos, Target, InPos )
	end

	local Phys	= Target:GetPhysicsObject()
	local Axis	= Phys:WorldToLocalVector( self:GetRight() )
	local Inertia	= ( Axis * Phys:GetInertia() ):Length()

	local Link = {
		Ent			= Target,
		Side		= Side,
		Axis		= Axis,
		Inertia		= Inertia,
		Rope		= Rope,
		RopeLen		= ( OutPosWorld - InPosWorld ):Length(),
		Output		= OutPos,
		ReqTq		= 0,
		Vel			= 0
	}
	table.insert( self.WheelLink, Link )

	return true, "Link successful!"

end

function ENT:Unlink( Target )

	for Key, Link in pairs( self.WheelLink ) do

		if Link.Ent == Target then

			-- Remove any old physical ropes leftover from dupes
			for _, Rope in pairs( constraint.FindConstraints( Link.Ent, "Rope" ) ) do
				if Rope.Ent1 == self or Rope.Ent2 == self then
					Rope.Constraint:Remove()
				end
			end

			if IsValid( Link.Rope ) then
				Link.Rope:Remove()
			end

			table.remove( self.WheelLink, Key )

			return true, "Unlink successful!"

		end

	end

	return false, "That entity is not linked to this gearbox!"

end

function ENT:PreEntityCopy()

	-- Link Saving
	local info = {}
	local entids = {}

	-- Clean the table of any invalid entities
	for Key, Link in pairs( self.WheelLink ) do
		if not IsValid( Link.Ent ) then
			table.remove( self.WheelLink, Key )
		end
	end

	-- Then save it
	for _, Link in pairs( self.WheelLink ) do
		table.insert( entids, Link.Ent:EntIndex() )
	end

	info.entities = entids
	if info.entities then
		duplicator.StoreEntityModifier( self, "WheelLink", info )
	end

	--Wire dupe info
	self.BaseClass.PreEntityCopy( self )

end

function ENT:PostEntityPaste( Player, Ent, CreatedEntities )

	-- Link Pasting
	if Ent.EntityMods and Ent.EntityMods.WheelLink and Ent.EntityMods.WheelLink.entities then
		local WheelLink = Ent.EntityMods.WheelLink
		if WheelLink.entities and next( WheelLink.entities ) then
			-- Dupe restoration applies entity parenting after PostEntityPaste.
			-- Delay rebuilding gearbox links until the pasted parent hierarchy
			-- has been restored, otherwise ACE_CreateLinkRope can capture the
			-- child endpoint as unparented and its offset becomes invalid once
			-- the parent is applied.
			timer.Simple( 0.1, function()
				if not IsValid( self ) then return end

				for _, ID in pairs( WheelLink.entities ) do
					local Linked = CreatedEntities[ ID ]
					if IsValid( Linked ) then
						self:Link( Linked )
					end
				end
			end )
		end
		Ent.EntityMods.WheelLink = nil
	end

	--Wire dupe info
	self.BaseClass.PostEntityPaste( self, Player, Ent, CreatedEntities )

end

function ENT:OnRemove()

	for Key in pairs(self.Master) do	--Let's unlink ourselves from the engines properly
		if IsValid( self.Master[Key] ) then
			self.Master[Key]:Unlink( self )
		end
	end

end
