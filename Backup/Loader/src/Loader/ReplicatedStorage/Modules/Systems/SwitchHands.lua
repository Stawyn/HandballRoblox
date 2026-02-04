local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local InputSystem = require("../Implementation/InputSystem")
local ClientNetwork = require("../Implementation/ClientNetwork")
local ThrowTool = require("./ToolsController/ThrowTool")

local localPlayer = Players.LocalPlayer :: Player
local playerGui = localPlayer.PlayerGui
local cooldown = false

local handsIndicator = playerGui:WaitForChild("Indicator"):WaitForChild("Arm")

InputSystem.Contexts.Hands.Enabled = true

InputSystem.Actions.Hands["Switch Hand"].Pressed:Connect(function()
	if cooldown then
		return
	end
	if ThrowTool:GetCharging() == true then
		return
	end
	cooldown = true


	ClientNetwork.SwitchHandsEvent:SwitchRequest()
	task.wait(0.5)

	cooldown = false
end)

function onArmChanged()
	handsIndicator.Text = localPlayer:GetAttribute("CurrentHand")
	handsIndicator.TextColor3 = Color3.fromRGB(15, 23, 42)
	TweenService:Create(handsIndicator, TweenInfo.new(0.5), {
		TextColor3 = Color3.fromRGB(255, 255, 255)
	}):Play()
end

coroutine.wrap(onArmChanged)()
localPlayer:GetAttributeChangedSignal("CurrentHand"):Connect(onArmChanged)

return {}