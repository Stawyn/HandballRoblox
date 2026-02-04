local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ASSETS_FOLDER = ReplicatedStorage:WaitForChild("Assets")
local HOME_PENALTY = ASSETS_FOLDER.Penalty.Home :: BasePart
local AWAY_PENALTY = ASSETS_FOLDER.Penalty.Away :: BasePart
local SpawnTool = {}

local ClientNetwork = require("../../Implementation/ClientNetwork")
local Janitor = require("../../../Utilities/Janitor")
local InputSystem = require("../../Implementation/InputSystem")

local localPlayer = Players.LocalPlayer :: Player
local penaltyPart: BasePart?

function ToggleColor(part: BasePart?, n: number)
	if not part then
		return
	end
	
	if n == 0 then
		part.Color = Color3.fromRGB(0, 0, 255)
	else
		part.Color = Color3.fromRGB(255, 0, 0)
	end
end

function getClosestGLT(position: Vector3)
	local closest
	local distance = math.huge
	
	for _, v in workspace.Core.GLT:GetChildren() do
		local distanceToGLT = (v.Position - position).Magnitude
		if distanceToGLT < distance then
			distance = distanceToGLT
			closest = v
		end
	end
	
	return closest
end

function createPart(glt)
	if penaltyPart then
		if penaltyPart.Name ~= glt.Name then
			penaltyPart:Destroy()
			penaltyPart = nil
		end
	end
	
	if not penaltyPart then
		if glt.Name == "Home" then
			penaltyPart = HOME_PENALTY:Clone()
			penaltyPart.Parent = workspace
		elseif glt.Name == "Away" then
			penaltyPart = AWAY_PENALTY:Clone()
			penaltyPart.Parent = workspace
		end
	end
end


function SpawnTool:Initialize(tool: Tool)	
	local toolJanitor = Janitor.new()
	-- Let n be a positive integer. currentTeam will be given as: currentTeam := n (mod 2) where:
	-- 0 := Home Team
	-- 1 := Away Team
	local currentTeam = 0
	local closest
	
	toolJanitor:LinkToInstance(tool)
	
	tool.Equipped:Connect(function()
		InputSystem.Contexts["Penalty Tool"].Enabled = true

		toolJanitor:Add(RunService.RenderStepped:Connect(function()
			closest = getClosestGLT(localPlayer:GetMouse().Hit.Position)
			createPart(closest)
			ToggleColor(penaltyPart, currentTeam)
		end))
		
		toolJanitor:Add(InputSystem.Actions["Penalty Tool"].Spawn.Pressed:Connect(function()
			local isHome = currentTeam == 0
			local isHomeGLT = closest.Name == "Home"
			ClientNetwork.RefereeEvent:RefPenalty(isHome, isHomeGLT)
		end), "Disconnect")
		
		toolJanitor:Add(InputSystem.Actions["Penalty Tool"]["Change Team"].Pressed:Connect(function()
			-- Change Team
			currentTeam = (currentTeam + 1) % 2
			ToggleColor(penaltyPart, currentTeam)
		end), "Disconnect")
	end)

	tool.Unequipped:Connect(function()
		InputSystem.Contexts["Penalty Tool"].Enabled = false
		
		if penaltyPart then
			penaltyPart:Destroy()
			penaltyPart = nil
		end
		
		closest = nil
		toolJanitor:Cleanup()
	end)

	tool.Destroying:Connect(function()
		if penaltyPart then
			penaltyPart:Destroy()
			penaltyPart = nil
		end
		
		closest = nil
	end)
end

return SpawnTool