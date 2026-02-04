local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local WorkSpace = game:GetService("Workspace")

local teleportedPlayers = {}

for _, Part in CollectionService:GetTagged("AntiInvade") do
	
	Part.Touched:Connect(function(hit)
		local Player = Players:GetPlayerFromCharacter(hit.Parent)

		if Player and Player.Team.Name == "Lobby" and not teleportedPlayers[Player] then	
			local playerCharacter = Player.Character :: Model		
			teleportedPlayers[Player] = true
			playerCharacter:PivotTo(WorkSpace.CrowdSpawn.SpawnLocation.CFrame + Vector3.new(0, 10, 0))
			task.wait(0.5)
			teleportedPlayers[Player] = false
		end
	end)
end