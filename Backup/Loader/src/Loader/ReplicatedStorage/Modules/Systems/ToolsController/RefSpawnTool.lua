local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ASSETS_FOLDER = ReplicatedStorage:WaitForChild("Assets")
local REFERENCE_BASEPART = ASSETS_FOLDER:WaitForChild("SpawnReference") :: {
	ForceField: BasePart
} & MeshPart
local SpawnTool = {}

local ClientNetwork = require("../../Implementation/ClientNetwork")
local Janitor = require("../../../Utilities/Janitor")
local InputSystem = require("../../Implementation/InputSystem")

local localPlayer = Players.LocalPlayer :: Player

function ToggleColor(part: BasePart, n: number)
	if n == 0 then
		part.Color = Color3.fromRGB(0, 0, 255)
	else
		part.Color = Color3.fromRGB(255, 0, 0)
	end
end

function SpawnTool:Initialize(tool: Tool)	
	local toolJanitor = Janitor.new()
	-- Let n be a positive integer. currentTeam will be given as: currentTeam := n (mod 2) where:
	-- 0 := Home Team
	-- 1 := Away Team
	local currentTeam = 0
	
	tool.Equipped:Connect(function()
		InputSystem.Contexts["Set Piece Tool"].Enabled = true
		
		local referenceClone = REFERENCE_BASEPART:Clone()
		toolJanitor:Add(referenceClone, "Destroy")
		referenceClone.Parent = workspace
		local position = Vector3.zero
		
		ToggleColor(referenceClone, currentTeam)
		
		toolJanitor:Add(RunService.RenderStepped:Connect(function(deltaTime)
			local mouseHit = localPlayer:GetMouse().Hit
			position = (mouseHit.Position * Vector3.new(1, 0, 1)) + Vector3.new(0, referenceClone.Size.Y/2, 0)

			referenceClone.CFrame = CFrame.new(position)
		end), "Disconnect")
		
		toolJanitor:Add(InputSystem.Actions["Set Piece Tool"].Spawn.Pressed:Connect(function()
			local isHome = currentTeam == 0
			ClientNetwork.RefereeEvent:RefSpawn(isHome, position)
		end), "Disconnect")
		
		toolJanitor:Add(InputSystem.Actions["Set Piece Tool"]["Change Team"].Pressed:Connect(function()
			currentTeam = (currentTeam + 1) % 2
			ToggleColor(referenceClone.ForceField, currentTeam)
		end))
	end)

	tool.Unequipped:Connect(function()
		InputSystem.Contexts["Set Piece Tool"].Enabled = false
		toolJanitor:Cleanup()
	end)

	tool.Destroying:Connect(function()
		toolJanitor:Destroy()
	end)
end

return SpawnTool