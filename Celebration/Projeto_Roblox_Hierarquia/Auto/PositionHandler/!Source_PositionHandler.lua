
local AutoService = require(game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("AutoService"))

local POSITIONS_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Positions")

for _, part: BasePart in pairs(POSITIONS_FOLDER:GetDescendants()) do
	if not part:IsA("BasePart") then continue end
	local teamName = part.Parent.Name
	part.Touched:Connect(function(partThatTouched)
		local player = game:GetService("Players"):GetPlayerFromCharacter(partThatTouched.Parent)
		if not player then return end
		if not player.Team.Name:find(teamName) then return end
		-- if AutoService:GetPlayerPosition(player) then return end		
		
		AutoService:AssignPlayerToPosition(player, part.Name)
	end)
end
