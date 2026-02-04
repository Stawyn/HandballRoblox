--[[
    ================================================================================
    MÓDULO: Stamina (Client)
    ================================================================================
    Descrição: Sistema de stamina/energia do jogador para controle de sprint e pulo.
    
    Funcionalidades:
        - Sprint: Aumenta velocidade enquanto consome stamina
        - Regeneração: Recupera stamina quando não está correndo
        - Pulo: Consome stamina ao pular
        - Exaustão: Impede sprint quando stamina chega a zero
    
    Configuração:
        - STAMINA_DURATION: Duração máxima do sprint (7s)
        - DRAIN_RATE: Taxa de consumo de stamina
        - INCREASE_RATE: Taxa de regeneração (20/s)
        - JUMP_DECREASE_RATE: Custo do pulo (24)
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: CONSTANTES DE CONFIGURAÇÃO
--// ============================================================================

local Stamina = {}

local STAMINA_DURATION = 7 -- Duração em segundos
local DRAIN_RATE = 100 / STAMINA_DURATION
local INCREASE_RATE = 20
local JUMP_DECREASE_RATE = 24
local RUN_REFRESH = 15

--// ============================================================================
--// SETOR: SERVIÇOS E DEPENDÊNCIAS
--// ============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StaminaUI = require("../Implementation/StaminaUI")
local SharedAttributes = require("../Implementation/SharedAttributes")
local InputSystem = require("../Implementation/InputSystem")

local STAMINA_EVENT = ReplicatedStorage:WaitForChild("Network"):WaitForChild("StaminaEvent")

--// ============================================================================
--// SETOR: ESTADO LOCAL
--// ============================================================================

local localPlayer = Players.LocalPlayer :: Player
local stamina = 100
local sprinting = false
local sprintHeld = false
local exhausted = false
local jumpCooldown = false

-- Listener servidor (correção/sincronia)
STAMINA_EVENT.OnClientEvent:Connect(function(action, value)
	if action == "ForceStopSprint" then
		sprinting = false
		exhausted = true
		sprintHeld = false -- Opcional, força soltar o botão
		Stamina:Sprint(false) -- Atualiza UI
	end
end)

-- UI Mobile
local mobileUI = localPlayer.PlayerGui:WaitForChild("Mobile")
local sprintFrame = mobileUI:WaitForChild("Sprint") :: Frame 
local sprintButton = sprintFrame:WaitForChild("Interact") :: TextButton

--// ============================================================================
--// SETOR: HANDLERS DE INPUT MOBILE
--// ============================================================================

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
	if exhausted and state then
		return
	end
	
	-- Lógica visual imediata (Prediction)
	sprinting = state
	
	-- Notificar servidor
	STAMINA_EVENT:FireServer("Sprint", state)
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
	
	-- Notificar servidor
	STAMINA_EVENT:FireServer("Jump")
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
