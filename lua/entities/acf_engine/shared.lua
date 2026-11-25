-- shared.lua

DEFINE_BASECLASS( "base_wire_entity" )

ENT.PrintName = "ACF Engine"
ENT.WireDebugName = "ACF Engine"

if SERVER then
	local function InstallBatteryCharging()
		local Stored = scripted_ents.GetStored( "acf_engine" )
		local Engine = Stored and Stored.t

		if not Engine or Engine.ACEBatteryChargingInstalled then return end
		Engine.ACEBatteryChargingInstalled = true

		local BatteryLinkDistance = 512

		local function FindFuelTank( Entity )
			for _, Tank in ipairs( Entity.FuelLink or {} ) do
				if IsValid( Tank ) and Tank.Active and Tank.Legal and Tank.Fuel > 0 and Tank.FuelType ~= "Electric" then
					return Tank
				end
			end
		end

		local function RemoveMasterLink( Battery, Entity )
			for Index, Master in ipairs( Battery.Master or {} ) do
				if Master == Entity then
					table.remove( Battery.Master, Index )
					return
				end
			end
		end

		--- Links an electric ACE battery to a petrol or diesel ACE engine for charging.
		-- The engine keeps its separate, normal fuel-tank links to run.
		-- @param Target Entity Electric ACE battery to link.
		-- @return boolean Whether the battery was linked.
		-- @return string Status message describing the result.
		function Engine:LinkBattery( Target )
			if self.FuelType == "Electric" then
				return false, "Only petrol or diesel engines can charge batteries."
			end

			if not IsValid( Target ) or Target:GetClass() ~= "acf_fueltank" or Target.FuelType ~= "Electric" then
				return false, "You can only link an electric battery for charging."
			end

			if Target.NoLinks then
				return false, "This battery doesn't allow linking."
			end

			if not Target.Legal then
				return false, "This battery is illegal."
			end

			if self:GetPos():DistToSqr( Target:GetPos() ) > BatteryLinkDistance ^ 2 then
				return false, "Battery is too far away."
			end

			self.BatteryLink = self.BatteryLink or {}

			for _, Battery in ipairs( self.BatteryLink ) do
				if Battery == Target then
					return false, "That battery is already linked to this engine."
				end
			end

			table.insert( self.BatteryLink, Target )
			Target.Master = Target.Master or {}
			table.insert( Target.Master, self )

			return true, "Battery linked for charging."
		end

		--- Unlinks an electric ACE battery from an engine charger.
		-- @param Target Entity Electric ACE battery to unlink.
		-- @return boolean Whether the battery was unlinked.
		-- @return string Status message describing the result.
		function Engine:UnlinkBattery( Target )
			for Index, Battery in ipairs( self.BatteryLink or {} ) do
				if Battery == Target then
					table.remove( self.BatteryLink, Index )
					if IsValid( Target ) then RemoveMasterLink( Target, self ) end
					return true, "Battery unlinked."
				end
			end

			return false, "That battery is not linked to this engine."
		end

		--- Charges linked electric batteries from a running, fueled petrol or diesel engine.
		-- @param DeltaTime number Time in seconds since the engine's previous calculation.
		function Engine:ChargeBatteries( DeltaTime )
			if not self.Active or not self.Legal or self.FuelType == "Electric" then return 0 end

			local FuelTank = FindFuelTank( self )
			local Efficiency = ACE.Efficiency[self.EngineType]
			local FuelDensity = FuelTank and ACE.FuelDensity[FuelTank.FuelType]
			local GeneratorEfficiency = ACE.Efficiency.Electric

			if not FuelTank or not Efficiency or not FuelDensity or not GeneratorEfficiency or GeneratorEfficiency <= 0 then return 0 end

			local Batteries = self.BatteryLink or {}
			local BatteryRoom = 0

			for Index = #Batteries, 1, -1 do
				local Battery = Batteries[Index]

				if not IsValid( Battery ) or self:GetPos():DistToSqr( Battery:GetPos() ) > BatteryLinkDistance ^ 2 then
					self:UnlinkBattery( Battery )
					continue
				end

				if Battery.FuelType == "Electric" and Battery.Active and Battery.Legal then
					BatteryRoom = BatteryRoom + math.max( Battery.Capacity - Battery.Fuel, 0 )
				end
			end

			if BatteryRoom <= 0 then return 0 end

			local Power = math.max( self.Torque or 0, 0 ) * math.max( self.FlyRPM or 0, 0 ) / 9548.8
			local MechanicalEnergy = Power * DeltaTime / 3600
		local ChargeEnergy = math.min( BatteryRoom, MechanicalEnergy * GeneratorEfficiency )

			if ChargeEnergy <= 0 then return 0 end

			-- Generator power is an additional load: deduct its fuel from the engine's
			-- own petrol/diesel tank, separately from the fuel it used to run this tick.
			local FuelNeeded = ChargeEnergy * Efficiency / (GeneratorEfficiency * FuelDensity)
			local FuelUsed = math.min( FuelNeeded, FuelTank.Fuel )
			ChargeEnergy = ChargeEnergy * FuelUsed / math.max( FuelNeeded, 0.000001 )

			if ChargeEnergy <= 0 then return 0 end

			FuelTank.Fuel = math.max( FuelTank.Fuel - FuelUsed, 0 )
			Wire_TriggerOutput( FuelTank, "Fuel", FuelTank.Fuel )

			local RemainingCharge = ChargeEnergy
			for _, Battery in ipairs( Batteries ) do
				if not IsValid( Battery ) or Battery.FuelType ~= "Electric" or not Battery.Active or not Battery.Legal then continue end

				local Room = math.max( Battery.Capacity - Battery.Fuel, 0 )
				local AddedCharge = math.min( Room, RemainingCharge )

				if AddedCharge > 0 then
					Battery.Fuel = Battery.Fuel + AddedCharge
					RemainingCharge = RemainingCharge - AddedCharge
					Wire_TriggerOutput( Battery, "Fuel", Battery.Fuel )
					Battery:UpdateFuelMass()
				end

				if RemainingCharge <= 0 then break end
			end

			return FuelUsed
		end

		local OriginalLink = Engine.Link
		if OriginalLink then
			Engine.Link = function( self, Target, ... )
				if self.FuelType ~= "Electric" and IsValid( Target ) and Target:GetClass() == "acf_fueltank" and Target.FuelType == "Electric" then
					return self:LinkBattery( Target )
				end

				return OriginalLink( self, Target, ... )
			end
		end

		local OriginalUnlink = Engine.Unlink
		if OriginalUnlink then
			Engine.Unlink = function( self, Target, ... )
				for _, Battery in ipairs( self.BatteryLink or {} ) do
					if Battery == Target then return self:UnlinkBattery( Target ) end
				end

				return OriginalUnlink( self, Target, ... )
			end
		end

		local OriginalCalcRPM = Engine.CalcRPM
		if OriginalCalcRPM then
			Engine.CalcRPM = function( self, ... )
				local DeltaTime = math.max( CurTime() - (self.LastThink or CurTime()), 0 )
				local FuelTank = FindFuelTank( self )
				local FuelBefore = IsValid( FuelTank ) and FuelTank.Fuel or 0
				local Result = OriginalCalcRPM( self, ... )
				local FuelUsed = self:ChargeBatteries( DeltaTime )

				if FuelUsed > 0 then
					if IsValid( FuelTank ) then
						Wire_TriggerOutput( self, "Fuel Use", math.Round( 60 * (FuelBefore - FuelTank.Fuel) / math.max( DeltaTime, 0.000001 ), 3 ) )
					end
				end

				return Result
			end
		end

		local OriginalPreEntityCopy = Engine.PreEntityCopy
		if OriginalPreEntityCopy then
			Engine.PreEntityCopy = function( self, ... )
				local Result = OriginalPreEntityCopy( self, ... )
				local Entities = {}

				for _, Battery in ipairs( self.BatteryLink or {} ) do
					if IsValid( Battery ) then Entities[#Entities + 1] = Battery:EntIndex() end
				end

				if #Entities > 0 then
					duplicator.StoreEntityModifier( self, "ACEBatteryLink", { entities = Entities } )
				end

				return Result
			end
		end

		local OriginalPostEntityPaste = Engine.PostEntityPaste
		if OriginalPostEntityPaste then
			Engine.PostEntityPaste = function( self, Player, Entity, CreatedEntities, ... )
				local LinkData = Entity.EntityMods and Entity.EntityMods.ACEBatteryLink
				local Result = OriginalPostEntityPaste( self, Player, Entity, CreatedEntities, ... )

				if LinkData and LinkData.entities then
					timer.Simple( 0, function()
						if not IsValid( self ) then return end

						for _, Index in ipairs( LinkData.entities ) do
							local Battery = CreatedEntities[Index]
							if IsValid( Battery ) then self:Link( Battery ) end
						end
					end )
				end

				return Result
			end
		end

		local OriginalOnRemove = Engine.OnRemove
		Engine.OnRemove = function( self, ... )
			for _, Battery in ipairs( self.BatteryLink or {} ) do
				if IsValid( Battery ) then RemoveMasterLink( Battery, self ) end
			end

			self.BatteryLink = {}
			if OriginalOnRemove then return OriginalOnRemove( self, ... ) end
		end
	end

	hook.Add( "InitPostEntity", "ACE.InstallBatteryCharging", InstallBatteryCharging )
end
