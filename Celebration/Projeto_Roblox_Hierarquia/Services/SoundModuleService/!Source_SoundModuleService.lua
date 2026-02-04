local SoundModuleService = {}

local SoundService = game:GetService("SoundService")

local cooldown: {[Sound]: boolean} = {}

function SoundModuleService:Play(soundInstace: Sound)
	task.spawn(function()
		if cooldown[soundInstace] then return end
		cooldown[soundInstace] = true
		soundInstace:Play()
		task.wait(soundInstace.TimeLength + .05)
		cooldown[soundInstace] = nil
	end)
end

return SoundModuleService

