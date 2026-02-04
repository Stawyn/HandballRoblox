local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Espera o Loader terminar de mover todos os arquivos
ReplicatedStorage:WaitForChild("LoaderReady")

local CardSystem = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Systems"):WaitForChild("CardSystem"))
local tool = script.Parent
local cardEvent = tool:WaitForChild("RemoteEvent")

cardEvent.OnServerEvent:Connect(function(player, target, message)
	
	if target ~= nil and target.Parent:FindFirstChild("Humanoid") then
		local localPlayer = Players:FindFirstChild(target.Parent.Name)
		if message == "Remove" then
			CardSystem:RemovePlayerCards(localPlayer)
		else
			CardSystem:GiveYellow(localPlayer)
		end
	end
end)