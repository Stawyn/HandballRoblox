local replicatedStorage = game:GetService("ReplicatedStorage")
local userInputService = game:GetService("UserInputService")

local utilityFunctions = require(replicatedStorage.Slider.utilityFunctions)
local Slider = require(replicatedStorage.Slider)

local slider = Slider.new(script.Parent.sliderHolder.slider, {
    values = {min = 95, max = 120},
    defaultValue = 110,
    canLeaveFrame = false,
    canFullyLeaveFrame = false,
    moveToMouse = true,

})

local function roundFunction(n: number): string
	return tostring(utilityFunctions.roundToDecimalPlaces(n, 2))
end

local function textMakerFunction(_string: string): string
	return `FOV: {_string}`
end

local tracker = slider:AddTracker(script.Parent.tracker, roundFunction, textMakerFunction)

local currentCamera = workspace.CurrentCamera
currentCamera.FieldOfView = slider:GetValue()

slider.moved:Connect(function()
    print(slider:GetValue())
	currentCamera.FieldOfView = slider:GetValue()
end)

userInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode ~= Enum.KeyCode.R then return end
	
	slider:Reset()
end)

slider:Enable()