local root = assert(arg[1], "usage: ace_points_model_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

ACE = {}
function istable(value) return type(value) == "table" end
function ACE.IsEnt(value) return value ~= nil end

dofile(root .. "/lua/acf/shared/sh_ace_points_model.lua")

-- New armor material pricing keys must be explicit (unknown IDs fall back to RHA).
local grapheneKE, grapheneHEAT = ACE.Points.MaterialEff("Graph")
assert(grapheneKE == 4.5 and grapheneHEAT == 4.0, "graphene composite premium pricing missing")
local aerogelKE, aerogelHEAT = ACE.Points.MaterialEff("Aero")
assert(aerogelKE == 2.2 and aerogelHEAT == 2.2, "aerogel premium pricing missing")
local diamondKE, diamondHEAT = ACE.Points.MaterialEff("Diam")
assert(diamondKE == 5.0 and diamondHEAT == 4.5, "diamond composite premium pricing missing")


local empty = { Type = "APHE", maxPen = 200, FrArea = math.pi * 5 ^ 2, blastMass = 0 }
local loaded = { Type = "APHE", maxPen = 200, FrArea = math.pi * 5 ^ 2, blastMass = 60 }

assert(ACE.Points.IntrinsicValueMul(empty) == 1.0,
	"zero-filler APHE must not receive HE utility value")
assert(ACE.Points.GatePen(empty) == empty.maxPen,
	"zero-filler APHE must retain only its kinetic penetration gate")
assert(ACE.Points.IntrinsicValueMul(loaded) == 1.5,
	"loaded APHE must receive HE payload value")
assert(ACE.Points.GatePen(loaded) > ACE.Points.GatePen(empty),
	"loaded APHE filler must add HE-equivalent threat reach")
assert(ACE.Points.BaseRoundCost(loaded) > ACE.Points.BaseRoundCost(empty),
	"loaded APHE filler must add round cost")

local primitive = {
	GetClass = function() return "prop_physics" end,
	ACF = { MaxArmour = 100, MaxHealth = 100 },
}
assert(ACE.Points.PropArmor(primitive) ~= nil, "ordinary prop armor must remain priced")
primitive.ACE_PrimitivePropertiesPending = true
assert(ACE.Points.PropArmor(primitive) == nil,
	"Primitive armor must stay out of pricing while its properties are pending")

print("ACE points model LuaJIT self-test: PASS")
