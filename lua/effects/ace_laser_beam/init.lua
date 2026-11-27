local BeamMaterial = Material("cable/redlaser")
local GlowMaterial = Material("sprites/light_glow02_add")

function EFFECT:Init(Data)
	self.Start = Data:GetStart()
	self.End = Data:GetOrigin()
	self.Power = math.Clamp(Data:GetScale(), 0.5, 1.8)
	self.CaliberScale = math.Clamp(Data:GetMagnitude(), 0.1, 10)
	self.DieTime = CurTime() + 0.14
	self:SetRenderBoundsWS(self.Start, self.End)
end

function EFFECT:Think()
	return CurTime() < self.DieTime
end

function EFFECT:Render()
	local Alpha = math.Clamp((self.DieTime - CurTime()) / 0.14, 0, 1)
	local Width = (2.5 + self.Power * 2.5) * self.CaliberScale

	render.SetMaterial(BeamMaterial)
	render.DrawBeam(self.Start, self.End, Width, 0, 1, Color(255, 220, 40, 255 * Alpha))
	render.DrawBeam(self.Start, self.End, Width * 0.35, 0, 1, Color(255, 255, 190, 255 * Alpha))

	render.SetMaterial(GlowMaterial)
	render.DrawSprite(self.Start, Width * 4, Width * 4, Color(255, 220, 35, 220 * Alpha))
	render.DrawSprite(self.End, Width * 6, Width * 6, Color(255, 235, 70, 200 * Alpha))
end
