DEFINE_BASECLASS( "base_wire_entity" )

-- Make this SENT actually inherit Wire entity behavior, not just reference its
-- base class for explicit method calls. Wire's looked-at overlay checks IsWire.
ENT.Base = "base_wire_entity"
ENT.IsWire = true

ENT.PrintName		= "ACF Gun"
ENT.WireDebugName	= "ACF Gun"
