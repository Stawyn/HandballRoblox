type MaterialsTable = {
	[BasePart]: Enum.Material
}

local SettingsController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local SolarisLibModule = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("SolarisLibrary"))
local Maid = require(ReplicatedStorage:WaitForChild("Utils"):WaitForChild("Maid"))
local CrowdModule = require(ReplicatedStorage:WaitForChild("Utils"):WaitForChild("CrowdModule"))

do	
	local charactersMaid = Maid.new()
	local noDelayBallMaid = Maid.new()
	local materials: MaterialsTable = {}
	local lightings = {}
	
	for _, part: BasePart in pairs(workspace:GetDescendants()) do
		if not part:IsA("BasePart") then continue end
		materials[part] = part.Material
	end
	
	for _, lighting in pairs(Lighting:GetChildren()) do
		lightings[lighting] = lighting
	end
	
	local SolarisLib = SolarisLibModule:New({
		Name = "Settings"
	})
	
	local function ErrorNotification(message: string)
		SolarisLibModule:Notification("Error", message)
	end
	
	local settingsTab = SolarisLib:Tab("Settings")
	local performanceTab = settingsTab:Section("Performance")
	
	performanceTab:Toggle("Remove materials", false, "Toggle", function(state: boolean)
		if state then
			for _, part: BasePart in pairs(workspace:GetDescendants()) do
				if not part:IsA("BasePart") then continue end
				part.Material = Enum.Material.SmoothPlastic
			end
		else
			for part: BasePart, originalMaterial: Enum.Material in pairs(materials) do
				part.Material = originalMaterial
			end 
		end
	end)
	
	performanceTab:Toggle("Remove stadium", false, "Toggle", function(state: boolean)
		if state then
			local stadium: Folder = workspace:FindFirstChild("StadiumParts")
			if not stadium then return end
			stadium.Parent = ReplicatedStorage
		else
			local stadium: Folder = ReplicatedStorage:FindFirstChild("StadiumParts")
			if not stadium then return end
			stadium.Parent = workspace
		end
	end)
	
	performanceTab:Toggle("Remove field texture", false, "Toggle", function(state: boolean)
		if state then
			local field = workspace:WaitForChild("Core"):WaitForChild("Field"):WaitForChild("Field")
			field.SurfaceGui.Enabled = false
		else
			local field = workspace:WaitForChild("Core"):WaitForChild("Field"):WaitForChild("Field")
			field.SurfaceGui.Enabled = true
		end
	end)
	
	performanceTab:Toggle("Remove lightings", false, "Toggle", function(state: boolean)
		if state then
			for _, instance in pairs(lightings) do
				instance.Parent = ReplicatedStorage
			end
		else
			for _, instance in pairs(lightings) do
				instance.Parent = Lighting
			end
		end
	end)
	
	performanceTab:Toggle("Remove crowd(experimental)", false, "Toggle", function(state: boolean)
		CrowdModule:HandlePerformance(state)
	end)
	
	local miscTab = settingsTab:Section("Miscellaneous")
	
	miscTab:Toggle("No delay ball", false, "Toggle", function(state: boolean)
		if state then
			noDelayBallMaid:GiveTask(workspace:WaitForChild("Core"):WaitForChild("NoDelay").ChildAdded:Connect(function(noDelayPart)
				if not noDelayPart:IsA("BasePart") then return end
				noDelayPart.Transparency = 0
			end))
			for _, noDelayPart in pairs(workspace:WaitForChild("Core"):WaitForChild("NoDelay"):GetChildren()) do
				if not noDelayPart:IsA("BasePart") then continue end
				noDelayPart.Transparency = 0
			end
		else
			noDelayBallMaid:Destroy()
			for _, noDelayPart in pairs(workspace:WaitForChild("Core"):WaitForChild("NoDelay"):GetChildren()) do
				if not noDelayPart:IsA("BasePart") then continue end
				noDelayPart.Transparency = 1
			end
		end
	end)
	
	miscTab:Textbox("Day time(from 0 to 24)", true, function(value: string)
		local newTime = tonumber(value)
		if not newTime or newTime < 0 or newTime > 24 then
			ErrorNotification("You must insert a number from 0 to 24 to change the time of the day")
			return
		end
		Lighting.TimeOfDay = newTime
	end)

	miscTab:Textbox("Field of view", true, function(value: string)
		local newFOV = tonumber(value)
		if not newFOV then 
			ErrorNotification("You must insert a number to change the FOV")
			return 
		end
		
		workspace.CurrentCamera.FieldOfView = newFOV
	end)
	
	miscTab:Button("Reset field of view", function()
		workspace.CurrentCamera.FieldOfView = 70
	end)
	
	miscTab:Toggle("Remove Nets", false, "Toggle", function(state: boolean)
		if state then
			local nets: Folder = workspace:FindFirstChild("Core"):FindFirstChild("Nets")
			if not nets then return end
			nets.Parent = ReplicatedStorage
			for _, part: BasePart | Texture in pairs(workspace.Core.Goals:GetDescendants()) do
				if part.Name == "Post" then
					part.Transparency = 0.5
				elseif part:IsA("Texture") then
					part.Transparency = 1
				end
			end
		else
			local nets: Folder = ReplicatedStorage:FindFirstChild("Nets")
			if not nets then return end
			nets.Parent = workspace.Core
			for _, part: BasePart | Texture in pairs(workspace.Core.Goals:GetDescendants()) do
				if part.Name == "Post" then
					part.Transparency = 0
				elseif part:IsA("Texture") then
					part.Transparency = 0
				end
			end
		end
	end)
	
	miscTab:Toggle("Remove Scoreboard", false, "Toggle", function(state: boolean)
		local scoreboard: ScreenGui = Players.LocalPlayer.PlayerGui:WaitForChild("Scoreboard", math.huge)
		scoreboard.Enabled = not state
	end)
end

return SettingsController
