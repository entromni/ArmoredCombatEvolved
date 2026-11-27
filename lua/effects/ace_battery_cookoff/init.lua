-- Repeating thermite-like battery thermal runaway burst.
-- The server triggers this effect frequently while charge is being consumed.

function EFFECT:Init( data )
	local Origin = data:GetOrigin()
	local Emitter = ParticleEmitter( Origin )
	if not Emitter then return end

	-- White-hot core with a larger, brighter flare.
	local Core = Emitter:Add( "sprites/orangeflare1", Origin )
	if Core then
		Core:SetLifeTime( 0 )
		Core:SetDieTime( 0.3 )
		Core:SetStartAlpha( 230 )
		Core:SetEndAlpha( 0 )
		Core:SetStartSize( 52 )
		Core:SetEndSize( 6 )
		Core:SetColor( 255, 225, 150 )
		Core:SetLighting( false )
	end

	-- Dense upward flame and dark, expanding hot smoke.
	for _ = 1, 5 do
		local Flame = Emitter:Add( "effects/fire_cloud" .. math.random( 1, 2 ), Origin + Vector( 0, 0, math.Rand( 0, 14 ) ) )
		if Flame then
			Flame:SetVelocity( Vector( math.Rand( -32, 32 ), math.Rand( -32, 32 ), math.Rand( 150, 260 ) ) )
			Flame:SetLifeTime( 0 )
			Flame:SetDieTime( math.Rand( 0.45, 0.8 ) )
			Flame:SetStartAlpha( 170 )
			Flame:SetEndAlpha( 0 )
			Flame:SetStartSize( math.Rand( 20, 34 ) )
			Flame:SetEndSize( math.Rand( 48, 78 ) )
			Flame:SetColor( 255, math.random( 115, 180 ), math.random( 30, 65 ) )
			Flame:SetAirResistance( 35 )
			Flame:SetGravity( Vector( 0, 0, 25 ) )
		end
	end

	for _ = 1, 3 do
		local Smoke = Emitter:Add( "particle/smokesprites_000" .. math.random( 1, 9 ), Origin + Vector( 0, 0, 12 ) )
		if Smoke then
			Smoke:SetVelocity( Vector( math.Rand( -24, 24 ), math.Rand( -24, 24 ), math.Rand( 90, 180 ) ) )
			Smoke:SetLifeTime( 0 )
			Smoke:SetDieTime( math.Rand( 0.8, 1.5 ) )
			Smoke:SetStartAlpha( 130 )
			Smoke:SetEndAlpha( 0 )
			Smoke:SetStartSize( math.Rand( 18, 28 ) )
			Smoke:SetEndSize( math.Rand( 65, 100 ) )
			Smoke:SetColor( 70, 58, 45 )
			Smoke:SetAirResistance( 80 )
			Smoke:SetGravity( Vector( 0, 0, 45 ) )
		end
	end

	-- Strong, mostly vertical molten-metal spray. Particles are short-lived and
	-- gravity pulls the glowing trails back down after the initial jet.
	for _ = 1, 24 do
		local Spark = Emitter:Add( "effects/ar2_altfire1b", Origin + Vector( math.Rand( -7, 7 ), math.Rand( -7, 7 ), 5 ) )
		if Spark then
			Spark:SetVelocity( Vector( math.Rand( -65, 65 ), math.Rand( -65, 65 ), math.Rand( 420, 780 ) ) )
			Spark:SetLifeTime( 0 )
			Spark:SetDieTime( math.Rand( 0.65, 1.25 ) )
			Spark:SetStartAlpha( 255 )
			Spark:SetEndAlpha( 0 )
			Spark:SetStartSize( math.Rand( 3, 6 ) )
			Spark:SetEndSize( 0 )
			Spark:SetStartLength( math.Rand( 40, 75 ) )
			Spark:SetEndLength( 1 )
			Spark:SetColor( 255, math.random( 135, 220 ), math.random( 30, 75 ) )
			Spark:SetGravity( Vector( 0, 0, -520 ) )
			Spark:SetAirResistance( 16 )
			Spark:SetLighting( false )
			Spark:SetCollide( true )
			Spark:SetBounce( 0.25 )
		end
	end

	Emitter:Finish()
end

function EFFECT:Think()
	return false
end

function EFFECT:Render()
end
