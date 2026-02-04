local ShootingController = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local ballEvent: RemoteEvent = Remotes:WaitForChild("BallEvent")

local localPlayer: Player = Players.LocalPlayer

local chargeTime: number = 0.7
local power: number = 0
local shooting: boolean = false
local increaseRate: number = (100/chargeTime)

function TweenInterface()
	local powerProgress: Frame = localPlayer.PlayerGui:WaitForChild("Gameplay"):WaitForChild("Attributes"):WaitForChild("Power"):WaitForChild("Progress")
	TweenService:Create(powerProgress, TweenInfo.new(.05), { Size = UDim2.new(power / 100, 0, 1, 0) }):Play()
end

function ShootingController:SetState(state: boolean)
	shooting = state
end

function ShootingController:GetPower(): number
	return power
end

function Charge(deltaTime: number)
	power += increaseRate * deltaTime
	power = math.min(power, 100)
end

RunService.Heartbeat:Connect(function(deltaTime: number)
	if shooting then
		if power < 100 then
			Charge(deltaTime)
		end
		TweenInterface()
	else
		if power ~= 0 then
			power = 0
			TweenInterface()
		end
	end
end)

return ShootingController
