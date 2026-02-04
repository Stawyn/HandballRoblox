local Players = game:GetService("Players")

local SpawnTool = require("@self/SpawnTool")
local ThrowTool = require("@self/ThrowTool")
local KeeperTool = require("@self/KeeperTool")
local RefSpawnTool = require("@self/RefSpawnTool")
local PenaltySpawnTool = require("@self/PenaltySpawnTool")

local localPlayer = Players.LocalPlayer :: Player
local initializedTools = {} :: { [Tool]: boolean }

function initTool(tool: Tool) 
	if initializedTools[tool] then
		return
	end

	if tool.Name == "SpawnTool" then
		SpawnTool:Initialize(tool)
	elseif tool.Name == "ThrowTool" then
		ThrowTool:Initialize(tool)
	elseif tool.Name == "KeeperTool" then
		KeeperTool:Initialize(tool)
	elseif tool.Name == "RefSpawnTool" then
		RefSpawnTool:Initialize(tool)
	elseif tool.Name == "PenaltySpawnTool" then
		PenaltySpawnTool:Initialize(tool)
	end
	
	initializedTools[tool] = true
end

function onCharacterAdded(character: Model)
	local backpack = localPlayer:WaitForChild("Backpack") :: Backpack
	
	for _, tool in backpack:GetChildren() do
		if not tool:IsA("Tool") then
			continue
		end
		
		coroutine.wrap(initTool)(tool)
	end
	
	for _, tool in character:GetChildren() do
		if not tool:IsA("Tool") then
			continue
		end

		coroutine.wrap(initTool)(tool)
	end
	
	backpack.ChildAdded:Connect(function(tool)
		if not tool:IsA("Tool") then
			return
		end
		
		coroutine.wrap(initTool)(tool)
	end)
	
	character.ChildAdded:Connect(function(tool)
		if not tool:IsA("Tool") then
			return
		end
		
		coroutine.wrap(initTool)(tool)
	end)
end

local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
onCharacterAdded(character)
localPlayer.CharacterAdded:Connect(onCharacterAdded)

return {}