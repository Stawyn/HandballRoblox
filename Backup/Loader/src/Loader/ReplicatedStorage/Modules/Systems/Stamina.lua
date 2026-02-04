local Stamina = {}

local STAMINA_DURATION = 7 -- In seconds
local DRAIN_RATE = 100 / STAMINA_DURATION
local INCREASE_RATE = 20
local JUMP_DECREASE_RATE = 24
local RUN_REFRESH = 15

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")


local StaminaUI = require("../Implementation/StaminaUI")
local SharedAttributes = require("../Implementation/SharedAttributes")
local InputSystem = require("../Implementation/InputSystem")

local localPlayer = Players.LocalPlayer :: Player
local stamina = 100
local sprinting = false
local sprintHeld = false
local exhausted = false
local jumpCooldown = false

local mobileUI = localPlayer.PlayerGui:WaitForChild("Mobile")
local sprintFrame = mobileUI:WaitForChild("Sprint") :: Frame 
local sprintButton = sprintFrame:WaitForChild("Interact") :: TextButton

sprintButton.MouseButton1Click:Connect(function()
	sprintHeld = not sprintHeld
	Stamina:Sprint(sprintHeld)

	if sprintHeld then
		sprintFrame.BackgroundColor3 = Color3.fromRGB(0, 77, 0)
		sprintFrame.UIStroke.Enabled = false
		sprintButton.Text = "Sprinting"
	else
		sprintFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		sprintFrame.UIStroke.Enabled = true
		sprintButton.Text = "Sprint"
	end
end)

InputSystem.Contexts.Physical.Enabled = true 


function Stamina:ChargeStamina(state: boolean, deltaTime: number)	
	StaminaUI:TweenLastProgress(stamina)

	local rateChange: number
	if state then
		rateChange = -DRAIN_RATE
	else
		rateChange = INCREASE_RATE
	end

	stamina = math.clamp(stamina + (deltaTime * rateChange), 0, 100)
	StaminaUI:TweenProgress(deltaTime, stamina)
end

local REGEN_DELAY = 0.25 -- rlx o pai sabe oq faz
local lastSprintTime = 0

function Stamina:Sprint(state: boolean)
	if exhausted then
		return
	end
	local character = localPlayer.Character
	if not character then
		return
	end

	if character:FindFirstChild("KeeperTool") then
		sprinting = false
		return
	end

	local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
	if not humanoid then
		return
	end

	if state then
		humanoid.WalkSpeed = SharedAttributes:GetSprintSpeed()
	else
		humanoid.WalkSpeed = SharedAttributes:GetWalkSpeed()
		lastSprintTime = os.clock()
	end

	sprinting = state
end

function Stamina:ChargeByValue(value: number)
	StaminaUI:TweenLastProgress(stamina)
	stamina = math.clamp(stamina - value, 0, 100)
end

function Stamina:Jump()
	local character = localPlayer.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
	if not humanoid then
		return
	end

	if humanoid.FloorMaterial == Enum.Material.Air then 
		return
	end
	if stamina < JUMP_DECREASE_RATE then
		return
	end

	-- Bloqueia pulo se o jogador estiver com a bola (dentro do Force Field)
	local workspace = game:GetService("Workspace")
	local core = workspace:FindFirstChild("Core")
	if core then
		local ballsFolder = core:FindFirstChild("Balls")
		if ballsFolder then
			for _, ball in pairs(ballsFolder:GetChildren()) do
				local forceField = ball:FindFirstChild("ForceField")
				if forceField and forceField:GetAttribute("TakerUserId") == localPlayer.UserId then
					return
				end
			end
		end
	end

	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	Stamina:ChargeByValue(JUMP_DECREASE_RATE)
end

InputSystem.Actions.Physical.Sprint.Pressed:Connect(function()
	sprintHeld = true
	Stamina:Sprint(sprintHeld)
end)

InputSystem.Actions.Physical.Sprint.Released:Connect(function()
	sprintHeld = false
	Stamina:Sprint(sprintHeld)
end)

UserInputService.JumpRequest:Connect(function()
	if jumpCooldown then 
		return
	end
	jumpCooldown = true

	Stamina:Jump()
	task.wait(0.25) -- :P

	jumpCooldown = false
end)
RunService.Heartbeat:Connect(function(deltaTime)
	local character = localPlayer.Character
	local isMoving = false

	if character then
		local tool = character:FindFirstChild("KeeperTool")
		if tool then
			sprinting = false
		end

		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid and humanoid.MoveDirection.Magnitude > 0 then
			isMoving = true
		end
	end

	if sprinting and isMoving then
		if stamina > 0 then
			Stamina:ChargeStamina(true, deltaTime) 
		else
			Stamina:Sprint(false)
			exhausted = true
		end
	else 
		if (os.clock() - lastSprintTime) > REGEN_DELAY then
			if stamina < 100 then
				Stamina:ChargeStamina(false, deltaTime)

				if stamina > RUN_REFRESH then
					exhausted = false

					if sprintHeld then
						Stamina:Sprint(sprintHeld)
					end 
				end
			end
		end
	end

	StaminaUI:TweenProgress(stamina)
end)

return Stamina
