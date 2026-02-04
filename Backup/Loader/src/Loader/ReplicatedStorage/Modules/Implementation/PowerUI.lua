local TWEEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quart)

local PowerUI = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer :: Player
local playerGui = localPlayer.PlayerGui
local indicatorUI = playerGui:WaitForChild("Indicator", math.huge)
local mainUI = indicatorUI:WaitForChild("Main")
local powerUI = mainUI:FindFirstChild("Power") :: Frame
local powerIndicatorUI = powerUI:FindFirstChild("Indicator") :: Frame
local powerProgressUI = powerIndicatorUI:FindFirstChild("Progress") :: Frame
local fixedPowerUI = powerProgressUI:FindFirstChild("FixedPower") :: Frame

-- Improved Colors
local COLORS = {
	FULL = Color3.fromRGB(46, 204, 113),    -- Modern Green
	MEDIUM = Color3.fromRGB(241, 196, 15),  -- Modern Yellow
	CRITICAL = Color3.fromRGB(231, 76, 60), -- Modern Red
	FIXED_GAIN = Color3.fromRGB(46, 204, 113),
	FIXED_LOSS = Color3.fromRGB(192, 57, 43)
}

local function getPowerColor(percentage)
	if percentage > 0.6 then
		return COLORS.FULL
	elseif percentage > 0.25 then
		return COLORS.MEDIUM
	else
		return COLORS.CRITICAL
	end
end

-- Stylize Power UI
local function stylizePower()
	local function addCorner(parent, radius)
		local corner = parent:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, radius or 6)
		corner.Parent = parent
	end

	local function addStroke(parent, color, thickness)
		local stroke = parent:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
		stroke.Color = color or Color3.fromRGB(60, 60, 70)
		stroke.Thickness = thickness or 2
		stroke.Parent = parent
	end

	if powerUI then
		powerUI.BackgroundTransparency = 1
		-- addCorner(powerUI, 8)
		-- addStroke(powerUI)
	end

	if powerIndicatorUI then
		powerIndicatorUI.BackgroundColor3 = Color3.fromRGB(242, 246, 250)
		powerIndicatorUI.BackgroundTransparency = 0
	end

	if powerProgressUI then
		addCorner(powerProgressUI, 4)
	end
end
task.spawn(stylizePower)

function PowerUI:UpdatePower(power: number, fixedPower: number)
	local powerScale = power / 100
	local fixedPowerScale = 1 - (fixedPower / 100)
	local targetColor = getPowerColor(powerScale)

	-- Smooth bar updates using Lerp for heartbeat-ready updates or Tween for discrete updates
	-- Since this is called from Heartbeat in ThrowTool, we'll keep using Lerp or just direct set
	-- But to make it "like StaminaUI", we should provide methods

	powerProgressUI.Size = powerProgressUI.Size:Lerp(UDim2.fromScale(powerScale, 1), 0.3)
	powerProgressUI.BackgroundColor3 = powerProgressUI.BackgroundColor3:Lerp(targetColor, 0.15)

	fixedPowerUI.Size = fixedPowerUI.Size:Lerp(UDim2.fromScale(fixedPowerScale, 1), 0.3)

	local targetFixedColor = if fixedPowerScale < 0 then COLORS.FIXED_GAIN else COLORS.FIXED_LOSS
	fixedPowerUI.BackgroundColor3 = fixedPowerUI.BackgroundColor3:Lerp(targetFixedColor, 0.15)
end

return PowerUI
