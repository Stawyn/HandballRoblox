local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Controllers = ReplicatedStorage:WaitForChild("Controllers")
local StaminaController = require(Controllers:WaitForChild("StaminaController"))
local PlayerTypes = require(ReplicatedStorage:WaitForChild("Types"):WaitForChild("PlayerTypes"))
local KeeperController = require(Controllers:WaitForChild("KeeperController"))

local localPlayer: Player = Players.LocalPlayer

local character: PlayerTypes.Character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
character:WaitForChild("Humanoid"):SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
KeeperController:ResetCooldown()

local sprintKey: Enum.KeyCode | nil = nil

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then return end
		if localPlayer:GetAttribute("SetPiece") == true then return end
	if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.F then
		sprintKey = input.KeyCode
		StaminaController:Sprint()
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then return end
	if localPlayer:GetAttribute("SetPiece") == true then return end
	if input.KeyCode ~= Enum.KeyCode.F and input.KeyCode ~= Enum.KeyCode.LeftControl then return end

	if input.KeyCode == sprintKey then
		sprintKey = nil
		StaminaController:StopSprint()
	end
end)

