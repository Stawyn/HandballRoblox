local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CardSystem = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Systems"):WaitForChild("CardSystem"))
local tool = script.Parent
local cardEvent = tool:WaitForChild("RemoteEvent")

cardEvent.OnServerEvent:Connect(function(player, target, message)
	-- VALIDAR SE É OFFICIAL (Crítico #1: Segurança)
	if not player.Team or player.Team.Name ~= "Officials" then
		warn("[AntiHack] Non-official tried to give yellow card:", player.Name)
		return
	end
	
	if target ~= nil and target.Parent:FindFirstChild("Humanoid") then
		local localPlayer = Players:FindFirstChild(target.Parent.Name)
		if message == "Remove" then
			CardSystem:RemovePlayerCards(localPlayer)
		else
			CardSystem:GiveYellow(localPlayer)
		end
	end
end)