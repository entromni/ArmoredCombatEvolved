AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_menu.lua")

include("shared.lua")

util.AddNetworkString(SWEP.AmmoNetChannel)

net.Receive(SWEP.AmmoNetChannel, function(_, ply)
	local weapon = net.ReadEntity()

	if not IsValid(weapon) or weapon:GetClass() ~= "weapon_ace_amr" then return end
	if weapon:GetOwner() ~= ply then return end
	if weapon.NextAmmoSwap and weapon.NextAmmoSwap > CurTime() then return end

	weapon.NextAmmoSwap = CurTime() + 0.2

	local ammoType = net.ReadString()
	local values = {}

	for index = 1, 5 do
		values[index] = net.ReadFloat()
	end

	weapon:ApplyAmmo(ammoType, values, ply)
end)

function SWEP:Initialize()
	local base = weapons.Get("weapon_ace_base")

	if base and base.Initialize then
		base.Initialize(self)
	end

	self:PushAmmoState()
end
