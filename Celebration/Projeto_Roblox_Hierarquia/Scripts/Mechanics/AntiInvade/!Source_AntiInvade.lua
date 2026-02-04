local Players = game:GetService("Players")
local crowdTeam = game:GetService("Teams"):FindFirstChild("Crowd")

local matchValue = workspace:WaitForChild("Core"):WaitForChild("Stats"):WaitForChild("Match")

function onPartTouched(part)
	local character = part.Parent
	local player = Players:GetPlayerFromCharacter(character)

	if player and player.Team == crowdTeam and matchValue.Value ~= "Training" then
		player:LoadCharacter()
	end
end

-- workspace.AntiInvade.Touched:Connect(onPartTouched)

