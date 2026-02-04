local PlayerTypes = require(game:GetService("ReplicatedStorage"):WaitForChild("Types"):WaitForChild("PlayerTypes"))

local StaminaController = {}

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local localPlayer: Player = Players.LocalPlayer

local stamianDuration: number = 10
local stamina: number = 100
local drainRate: number = (100/stamianDuration)
local increaseRate: number = 25
local runRefresh: number = 20

local sprinting: boolean = false
local sprintHeld: boolean = false
local exhausted: boolean = false

function Sprint(springState: boolean)
	local character: PlayerTypes.Character? = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	local humanoid: Humanoid = character.Humanoid
	
	if exhausted then return end
	if not humanoid then return end
	if springState then
		humanoid.WalkSpeed = 28
	else
		humanoid.WalkSpeed = 20
	end
	sprinting = springState
end

function TweenInterface()
	local staminaProgressFrame: Frame? = localPlayer.PlayerGui:WaitForChild("Gameplay"):WaitForChild("Attributes"):WaitForChild("Stamina"):WaitForChild("Progress")
	TweenService:Create(staminaProgressFrame, TweenInfo.new(.05), { Size = UDim2.new(stamina / 100, 0, 1, 0) }):Play()
end

function StaminaController:CheckState()
	return sprinting
end

function StaminaController:GetFullState()
	return {
		sprinting = sprinting,
		stamina = stamina,
		exhausted = exhausted,
		sprintHeld = sprintHeld
	}
end

function StaminaController:Sprint()
	sprintHeld = true
	Sprint(sprintHeld)
end

function StaminaController:StopSprint()
	sprintHeld = false
	Sprint(sprintHeld)
end

function Charge(charging: boolean, deltaTime: number)
	if charging then
		stamina -= drainRate * deltaTime
	else
		stamina += increaseRate * deltaTime
	end
	
	stamina = math.min(stamina, 100)
end

RunService.Heartbeat:Connect(function(deltaTime: number)
	if localPlayer:GetAttribute("SetPiece") == true then 
		if not localPlayer.Character:FindFirstChild("Humanoid") then return end
		localPlayer.Character.Humanoid.WalkSpeed = 0
		return 
	end
	
	if sprinting then
		if stamina > 0 then
			Charge(true, deltaTime)
		else
			Sprint(false)
			exhausted = true
		end
		TweenInterface()
	elseif stamina < 100 then
		Charge(false, deltaTime)
		
		if stamina > runRefresh then
			exhausted = false
			if sprintHeld then Sprint(sprinting) end
		end
		TweenInterface()
	end
end)


return StaminaController
