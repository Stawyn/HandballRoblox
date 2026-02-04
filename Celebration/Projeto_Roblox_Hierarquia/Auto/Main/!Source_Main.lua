local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GAMECONFIG = ReplicatedStorage:WaitForChild("Config")
local AutoService = require(ServerScriptService:WaitForChild("Services"):WaitForChild("AutoService"))

local SetPiece = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SetPiece")
local Keeper = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Keeper")

local MINIMUM_PLAYERS = GAMECONFIG.MINIMUM_PLAYERS.Value

function OnPlayerAdded(player: Player)
	if #Players:GetPlayers() >= MINIMUM_PLAYERS then
		AutoService:StartIntermission()
	else
		AutoService:StopIntermission()
	end

	player:GetAttributeChangedSignal("SetPiece"):Connect(function()
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid = character:WaitForChild("Humanoid")
		if player:GetAttribute("SetPiece") == true then
			humanoid.WalkSpeed = 0
		else
			humanoid.WalkSpeed = 20
		end
	end)
end

SetPiece.OnServerEvent:Connect(function(player: Player)
	AutoService:AssignSetPiece(player)
end)
Keeper.OnServerEvent:Connect(function(player: Player, argument)
	if argument == "Keeper" then
		AutoService:AssignPlayerToGK(player)
	end
end)

Players.PlayerAdded:Connect(OnPlayerAdded)
for i, v in pairs(Players:GetPlayers()) do
	task.spawn(OnPlayerAdded, v)
end
