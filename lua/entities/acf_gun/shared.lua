DEFINE_BASECLASS( "base_wire_entity" )


ENT.PrintName		= "ACF Gun"
ENT.WireDebugName	= "ACF Gun"

--- Rebuilds this gun's collision mesh at a uniform scale. Used on both realms.
-- @param Scale number Uniform scale relative to the unscaled model.
-- @return boolean True if the scaled physics object was created.
function ENT:ACE_ApplyScaledCollision(Scale)
	self:PhysicsInit(SOLID_VPHYSICS) -- Always start from the unscaled model mesh

	local Phys = self:GetPhysicsObject()
	if not IsValid(Phys) then return false end

	local Convexes = Phys:GetMeshConvexes()
	if not Convexes then return false end

	local Scaled = {}
	for Index, Convex in ipairs(Convexes) do
		local Points = {}
		for Key, Vertex in ipairs(Convex) do
			Points[Key] = Vertex.pos * Scale
		end
		Scaled[Index] = Points
	end

	if not self:PhysicsInitMultiConvex(Scaled) then return false end

	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:EnableCustomCollisions(true)

	return IsValid(self:GetPhysicsObject())
end
