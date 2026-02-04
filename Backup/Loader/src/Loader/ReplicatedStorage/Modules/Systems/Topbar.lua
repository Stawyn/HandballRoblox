local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

local Icon = require("../../Utilities/Icon")
local ClientNetwork = require("../Implementation/ClientNetwork")
local InputSystem = require("../Implementation/InputSystem")
local Janitor = require("../../Utilities/Janitor")

local UserInputService = game:GetService("UserInputService")
local isMobile = UserInputService.TouchEnabled

local NETWORK_FOLDER = ReplicatedStorage:WaitForChild("Network") :: Folder
local BALLS_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Balls")
local LEAGUE_EVENT = NETWORK_FOLDER:WaitForChild("LeagueEvent") :: RemoteEvent

local localPlayer = Players.LocalPlayer :: Player
local playerGui = localPlayer.PlayerGui
local leagueWarningsUI = playerGui:WaitForChild("LeagueWarnings")
local warningTextLabel = leagueWarningsUI:WaitForChild("Warnings") :: TextLabel
local refUI = playerGui:WaitForChild("RefereeUI", math.huge) :: ScreenGui
local abhMenu = playerGui:WaitForChild("ABHMenu", math.huge) :: ScreenGui
local blur = Lighting.Blur
local menuIcon = Icon.new()
local ballcamIcon = Icon.new()
local pauseIcon = Icon.new()
local statsIcon = Icon.new()
local generalJanitor = Janitor.new()

local isExpanded = false
local separatorBars = {}

local function updateIconVisibility(icon)
	if icon then
		icon:deselect()
		icon:setEnabled(isExpanded)
	end

	for _, bar in ipairs(separatorBars) do
		bar.Visible = isExpanded
	end
end

-- Custom Theme for Bigger Icons
local BIG_THEME = {
	{"Widget", "MinimumWidth", 40}, -- Reduced from 48
	{"Widget", "MinimumHeight", 40}, -- Reduced from 48
	{"IconLabel", "TextSize", 20}, -- Reduced from 24
	{"IconImageScale", "Value", 0.75},
	{"IconCorners", "CornerRadius", UDim.new(0.35, 0)},
	{"PaddingLeft", "Size", UDim2.new(0, 0, 1, 0)}, -- Centering fix
	{"PaddingRight", "Size", UDim2.new(0, 0, 1, 0)}, -- Centering fix
}

local topbarToggle = Icon.new()
topbarToggle:setName("TopbarToggle")
	:setOrder(-10)
	:setLabel(">")
	:setTheme(BIG_THEME) -- Apply larger theme
	:bindEvent("selected", function()
		isExpanded = not isExpanded
		topbarToggle:setLabel(isExpanded and "<" or ">")

		updateIconVisibility(ballcamIcon)
		updateIconVisibility(menuIcon)
		updateIconVisibility(statsIcon)

		local refIcon = Icon.getIcon("RefereeUI")
		updateIconVisibility(refIcon)

		if pauseIcon then
			-- Check if pauseIcon is a valid Icon object before updating
			-- (it might be newly created or destroyed)
			updateIconVisibility(pauseIcon)
		end
	end)
	:oneClick(true)

local PAUSE_COOLDOWN = 30

local pauseCooldown = false
local ballcamActive = false

ballcamIcon:setName("Menu")
	:setLabel("⚙️")
	:setTextFont("RobotoMono", Enum.FontWeight.Bold)
	:setOrder(3)
	:setTheme(BIG_THEME) -- Apply larger theme
	:bindEvent("deselected", function()
		if abhMenu.Enabled == false then
			abhMenu.Enabled = true
			blur.Size = 100
		else
			abhMenu.Enabled = false
			blur.Size = 4
		end
	end)
	:oneClick(true)

updateIconVisibility(ballcamIcon)

-- F8 Shortcut to toggle ABHMenu
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.F8 then
		if abhMenu.Enabled == false then
			abhMenu.Enabled = true
			blur.Size = 100
		else
			abhMenu.Enabled = false
			blur.Size = 4
		end
	end
end)

menuIcon
	:setName("BallCamera")
	:setLabel("⚽")
	:setOrder(2)
	:setTheme(BIG_THEME) -- Apply larger theme
	:setTextFont("RobotoMono", Enum.FontWeight.Bold)
	:bindEvent("deselected", function()
		ballcamActive = not ballcamActive

		if ballcamActive then
			local ball = BALLS_FOLDER:GetChildren()[1]
			if not ball then
				ballcamActive = false
				return
			end

			workspace.CurrentCamera.CameraSubject = ball
		else
			workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
			workspace.CurrentCamera.CameraSubject = localPlayer.Character:WaitForChild("Humanoid", math.huge)
		end
	end)
	:oneClick(true)

BALLS_FOLDER.ChildAdded:Connect(function(newBall)
	if ballcamActive then
		local currentSubject = workspace.CurrentCamera.CameraSubject
		if not currentSubject or not currentSubject.Parent then
			workspace.CurrentCamera.CameraSubject = newBall
		end
	end
end)

updateIconVisibility(menuIcon)

-- Modern Divider Creator
local function createVerticalBar(order)
	local bar = Instance.new("Frame")
	bar.Name = "TopbarSeparator_" .. (order or "0")
	bar.Size = UDim2.new(0, 1, 0, 18) -- Shorter and thinner
	bar.BackgroundColor3 = Color3.new(1, 1, 1)
	bar.BackgroundTransparency = 0.8
	bar.BorderSizePixel = 0
	bar.LayoutOrder = order or 1000
	bar.Active = false

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.4),
		NumberSequenceKeypoint.new(1, 1)
	})
	gradient.Parent = bar

	table.insert(separatorBars, bar)
	bar.Visible = isExpanded

	task.spawn(function()
		local parent = nil
		while not parent do
			parent = Icon.TopbarFrame
			if not parent then task.wait(0.5) end
		end
		bar.Parent = parent
	end)
	return bar
end

-- Primary group separator
createVerticalBar(990)

-- Bindable for internal UI communication
local toggleEvent = ReplicatedStorage:FindFirstChild("ToggleStatsUI")
if not toggleEvent then
	toggleEvent = Instance.new("BindableEvent")
	toggleEvent.Name = "ToggleStatsUI"
	toggleEvent.Parent = ReplicatedStorage
end

-- Stats Icon
statsIcon:setName("StatsToggle")
	:setLabel("📊")
	:setTextFont("RobotoMono", Enum.FontWeight.Bold)
	:setOrder(1)
	:setTheme(BIG_THEME) -- Apply larger theme
	:bindEvent("selected", function() -- Changed to "selected" for better responsiveness with oneClick
		toggleEvent:Fire()
	end)
	:bindEvent("deselected", function()
		-- Fallback if selected doesn't fire as expected
		toggleEvent:Fire()
	end)
	:oneClick(true)

updateIconVisibility(statsIcon)

function onTeamChanged()
	generalJanitor:Cleanup()
	local enabled = false

	local refIcon = Icon.getIcon("RefereeUI")
	if refIcon then
		refIcon:destroy()
	end

	if (localPlayer.Team :: Team).Name == "Officials" then
		InputSystem.Contexts["Referee General"].Enabled = true
		local refIcon = Icon.new()
		refIcon
			:setName("RefereeUI")
			:setLabel("🛡️")
			:setTextFont("RobotoMono", Enum.FontWeight.Bold)
			:setTheme(BIG_THEME) -- Apply larger theme
			:bindEvent("deselected", function()
				enabled = not enabled
				refUI.Enabled = enabled
			end)
			:oneClick(true)

		updateIconVisibility(refIcon)

		generalJanitor:Add(InputSystem.Actions["Referee General"]["Remove balls"].Pressed:Connect(function()
			ClientNetwork.RefereeEvent:RemoveBalls()
		end), "Disconnect")
	else
		generalJanitor:Cleanup()
		InputSystem.Contexts["Referee General"].Enabled = false
		if refIcon then
			refIcon:destroy()
		end
		refUI.Enabled = false
	end
end

coroutine.wrap(onTeamChanged)()
localPlayer:GetPropertyChangedSignal("Team"):Connect(onTeamChanged)

pauseIcon:destroy()

LEAGUE_EVENT.OnClientEvent:Connect(function(action)
	if action == "CHOOSEN_MANAGER" then
		if pauseIcon then
			pauseIcon:destroy()
		end

		pauseIcon = Icon.new()
		pauseIcon
			:setName("TechnicalPause")
			:setLabel("⏸️")
			:setTextFont("RobotoMono", Enum.FontWeight.Bold)
			:setTheme(BIG_THEME) -- Apply larger theme
			:bindEvent("deselected", function()
				if pauseCooldown then
					local clone = warningTextLabel:Clone()
					clone.Text = "You're on a cooldown of 30 seconds. Please try again later"
					clone.Visible = true 
					clone.Parent = leagueWarningsUI
					Debris:AddItem(clone, 7)
					return
				end
				pauseCooldown = true

				ClientNetwork.LeagueEvent:CallForTechnicalPause()

				task.wait(PAUSE_COOLDOWN)
				pauseCooldown = false
			end)
			:oneClick(true)

		updateIconVisibility(pauseIcon)
	elseif action == "REMOVED_MANAGER" then
		if pauseIcon then
			pauseIcon:destroy()
		end
	end
end)

return {}

