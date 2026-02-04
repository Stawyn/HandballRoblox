local character = script.Parent.Parent

local humanoid = character:WaitForChild("Humanoid", math.huge)

local particleL = game:GetService("ServerStorage").EffectsStorage.StaminaParticle:Clone()
local particleR = game:GetService("ServerStorage").EffectsStorage.StaminaParticle:Clone()

particleL.Enabled = false
particleR.Enabled = false

particleL.Parent = character["Left Leg"]
particleR.Parent = character["Right Leg"]

humanoid.Running:Connect(function(Speed)
	
	if Speed > 22 and humanoid.FloorMaterial == Enum.Material.Grass then
		
		particleL.Enabled = true
		particleR.Enabled = true
		
	elseif humanoid.Jumping == true then
		
		particleL.Enabled = false
		particleR.Enabled = false
		
	else
		
		particleL.Enabled = false
		particleR.Enabled = false
	end
end)