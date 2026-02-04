local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ServerStorage = game:GetService("ServerStorage")

function onPlayerAdded(player: Player)
	local function onCharacterAdded(character: Model)
		ServerStorage.KickTool:Clone().Parent = player.Backpack
		
		if string.find(player.Team.Name, "Goalkeeper") then
			ServerStorage.KeeperTool:Clone().Parent = player.Backpack
		elseif string.find(player.Team.Name, "Officials") then
			ServerStorage.RC:Clone().Parent = player.Backpack
			ServerStorage.YC:Clone().Parent = player.Backpack
			ServerStorage.Spray:Clone().Parent = player.Backpack
			ServerStorage.Whistle:Clone().Parent = player.Backpack
			ServerStorage.SpawnTool:Clone().Parent = player.Backpack
		end
		
		if game.PlaceId == 14306285450 then
			ServerStorage.SpawnTool:Clone().Parent = player.Backpack
		end
	end
	
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)
end

for _, player: Player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
