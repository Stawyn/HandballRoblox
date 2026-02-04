local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CrowdModule = {}

local CHARACTERS_FOLDER = ReplicatedStorage:WaitForChild("Others"):WaitForChild("Characters")

local Maid = require(ReplicatedStorage:WaitForChild("Utils"):WaitForChild("Maid"))

local crowdCharacterMaid = Maid.new()

local function HandleCharacterAdded(player: Player)
	crowdCharacterMaid:GiveTask(player.CharacterAdded:Connect(function(newCharacter)
		if newCharacter.Parent == CHARACTERS_FOLDER then return end
		if player.Team.Name ~= "Crowd" then return end
		newCharacter.Parent = CHARACTERS_FOLDER
	end))
end

function RemoveExistingCharacter(player: Player)
	local existingCharacter = player.Character or player.CharacterAdded:Wait()
	if existingCharacter then
		if player.Team.Name ~= "Crowd" then return end
		existingCharacter.Parent = CHARACTERS_FOLDER
	end
end

function HandleTeamChange(player: Player)
	crowdCharacterMaid:GiveTask(player:GetPropertyChangedSignal("Team"):Connect(function()
		RemoveExistingCharacter(player)
	end))
end

function CrowdModule:HandlePerformance(state: boolean)
	if state then
		for _, player in pairs(Players:GetPlayers()) do
			if player == Players.LocalPlayer then continue end
			RemoveExistingCharacter(player)
			HandleCharacterAdded(player)
		end

		crowdCharacterMaid:GiveTask(Players.PlayerAdded:Connect(function(player)
			RemoveExistingCharacter(player)
			HandleCharacterAdded(player)
			HandleTeamChange(player)
		end))
	else
		crowdCharacterMaid:Destroy()
		for _, character in pairs(CHARACTERS_FOLDER:GetChildren()) do
			character.Parent = workspace
		end 
	end
end

return CrowdModule
