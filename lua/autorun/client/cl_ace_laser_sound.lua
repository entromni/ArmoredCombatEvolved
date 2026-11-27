local LaserSounds = setmetatable({}, { __mode = "k" })

local function StopLaserSound(Gun)
	local Sound = LaserSounds[Gun]
	if not Sound then return end

	Sound:Stop()
	LaserSounds[Gun] = nil
end

hook.Add("Think", "ACE_SciFiLaserLoopSound", function()
	for _, Gun in ipairs(ents.FindByClass("acf_gun")) do
		if Gun:GetNW2Bool("ACE_LaserActive", false) then
			if LaserSounds[Gun] then continue end

			local Sound = CreateSound(Gun, "weapons/physcannon/energy_sing_loop4.wav")
			if not Sound then continue end

			Sound:SetSoundLevel(75)
			Sound:PlayEx(0.65, 100)
			LaserSounds[Gun] = Sound
		else
			StopLaserSound(Gun)
		end
	end
end)

hook.Add("EntityRemoved", "ACE_SciFiLaserLoopSoundCleanup", StopLaserSound)
