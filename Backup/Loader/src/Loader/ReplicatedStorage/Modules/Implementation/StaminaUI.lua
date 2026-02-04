local TWEEN_INFO = TweenInfo.new(0.75, Enum.EasingStyle.Quart)
local STAMINA_TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quart)

local StaminaUI = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer :: Player
local playerGui = localPlayer.PlayerGui
local staminaFrame = playerGui:WaitForChild("Indicator").Main.Stamina.Indicator
-- Isso Ã© garantido para que ambas as instÃ¢ncias existam
local staminaLastProgressUI = staminaFrame:FindFirstChild("LastProgress") :: Frame
local staminaProgressUI = staminaFrame:FindFirstChild("Progress") :: Frame

-- Improved Colors
local COLORS = {
	FULL = Color3.fromRGB(46, 204, 113),    -- Modern Green
	MEDIUM = Color3.fromRGB(241, 196, 15),  -- Modern Yellow
	CRITICAL = Color3.fromRGB(231, 76, 60), -- Modern Red
}

local function getStaminaColor(percentage)
	if percentage > 0.6 then
		return COLORS.FULL
	elseif percentage > 0.25 then
		return COLORS.MEDIUM
	else
		return COLORS.CRITICAL
	end
end

function StaminaUI:TweenLastProgress(stamina: number)
	TweenService:Create(staminaLastProgressUI, TWEEN_INFO, {
		Size = UDim2.fromScale(stamina / 100, 1)
	}):Play()
end

function StaminaUI:TweenProgress(stamina: number)
	local percentage = stamina / 100
	local targetColor = getStaminaColor(percentage)

	TweenService:Create(staminaProgressUI, STAMINA_TWEEN_INFO, {
		Size = UDim2.fromScale(percentage, 1),
		BackgroundColor3 = targetColor
	}):Play()
end

return StaminaUI
