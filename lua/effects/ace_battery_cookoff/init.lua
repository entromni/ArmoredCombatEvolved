-- Sustained battery thermal-runaway visuals. Spawned repeatedly by the server
-- while an electric fuel tank is discharging its remaining charge.

function EFFECT:Init( data )
	local Origin = data:GetOrigin()
	local Emitter = ParticleEmitter( Origin )
	if not Emitter then return end

	-- Bright hot core and a narrow, rising thermal plume.
	local Core = Emitter:Add( "sprites/orangeflare1", Origin )
	if Core then
		Core:SetLifeTime( 0 )
		Core:SetDieTime( 0.22 )
		Core:SetStartAlpha( 190 )
		Core:SetEndAlpha( 0 )
		Core:SetStartSize( 24 )
		Core:SetEndSize( 4 )
		Core:SetColor( 255, 190, 85 )
		Core:SetLighting( false )
	end

	for _ = 1, 2 do
		local Flame = Emitter:Add( "effects/fire_cloud" .. math.random( 1, 2 ), Origin + Vector( 0, 0, 5 ) )
		if Flame then
			Flame:SetVelocity( Vector( math.Rand( -14, 14 ), math.Rand( -14, 14 ), math.Rand( 65, 110 ) ) )
			Flame:SetLifeTime( 0 )
			Flame:SetDieTime( math.Rand( 0.35, 0.65 ) )
			Flame:SetStartAlpha( 95 )
			Flame:SetEndAlpha( 0 )
			Flame:SetStartSize( math.Rand( 12, 20 ) )
			Flame:SetEndSize( math.Rand( 30, 46 ) )
			Flame:SetColor( 255, 155, 55 )
			Flame:SetAirResistance( 45 )
			Flame:SetGravity( Vector( 0, 0, 18 ) )
		end
	end

	-- Thermite-like sparks: mostly vertical, with modest lateral scatter.
	for _ = 1, 7 do
		local Spark = Emitter:Add( "effects/ar2_altfire1b", Origin + Vector( 0, 0, 4 ) )
		if Spark then
			Spark:SetVelocity( Vector( math.Rand( -28, 28 ), math.Rand( -28, 28 ), math.Rand( 170, 340 ) ) )
			Spark:SetLifeTime( 0 )
			Spark:SetDieTime( math.Rand( 0.45, 0.9 ) )
			Spark:SetStartAlpha( 255 )
			Spark:SetEndAlpha( 0 )
			Spark:SetStartSize( math.Rand( 2, 4 ) )
			Spark:SetEndSize( 0 )
			Spark:SetStartLength( math.Rand( 18, 34 ) )
			Spark:SetEndLength( 2 )
			Spark:SetColor( 255, math.random( 125, 210 ), math.random( 35, 90 ) )
			Spark:SetGravity( Vector( 0, 0, -380 ) )
			Spark:SetAirResistance( 22 )
			Spark:SetLighting( false )
		end
	end

	Emitter:Finish()
end

function EFFECT:Think()
	return false
end

function EFFECT:Render()
end
