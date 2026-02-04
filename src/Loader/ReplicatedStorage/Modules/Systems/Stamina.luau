--[[
	================================================================================
	MÃ“DULO: Stamina
	================================================================================
	
	DescriÃ§Ã£o:
		Sistema de stamina (energia) do jogador.
		Gerencia o consumo de energia ao correr e pular, regeneraÃ§Ã£o e UI.
	
	DependÃªncias:
		- StaminaUI (Visual)
		- SharedAttributes (Valores de velocidade)
		- InputSystem (Entrada de comandos)
	
	Autor: Sistema ABH
	================================================================================
]]

--// ============================================================================
--// SETOR: ServiÃ§os
--// ============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// ============================================================================
--// SETOR: DependÃªncias
--// ============================================================================

-- Assumindo caminhos relativos originais para compatibilidade
local StaminaUI = require("../Implementation/StaminaUI")
local SharedAttributes = require("../Implementation/SharedAttributes")
local InputSystem = require("../Implementation/InputSystem")

local Stamina = {}

--// ============================================================================
--// SETOR: ConfiguraÃ§Ãµes e Constantes
--// ============================================================================

local STAMINA_DURATION = 7 			-- DuraÃ§Ã£o total em segundos se correr sem parar
local DRAIN_RATE = 100 / STAMINA_DURATION
local INCREASE_RATE = 20 			-- Taxa de regeneraÃ§Ã£o por segundo
local JUMP_DECREASE_RATE = 24 		-- Custo de stamina por pulo
local RUN_REFRESH = 15 				-- Stamina necessÃ¡ria para voltar a correr apÃ³s exaustÃ£o
local REGEN_DELAY = 0.25 			-- Tempo de espera antes de regenerar

--// ============================================================================
--// SETOR: Estado
--// ============================================================================

local localPlayer = Players.LocalPlayer :: Player
local stamina = 100
local sprinting = false
local sprintHeld = false
local exhausted = false
local jumpCooldown = false
local lastSprintTime = 0

--// ============================================================================
--// SETOR: Interface Mobile
--// ============================================================================

local mobileUI = localPlayer.PlayerGui:WaitForChild("Mobile")
local sprintFrame = mobileUI:WaitForChild("Sprint") :: Frame 
local sprintButton = sprintFrame:WaitForChild("Interact") :: TextButton

-- Inicializa o contexto de input fÃ­sico
InputSystem.Contexts.Physical.Enabled = true 

-- Configura botÃ£o da UI Mobile
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

--// ============================================================================
--// SETOR: FunÃ§Ãµes Principais
--// ============================================================================

--[[
	Atualiza o valor da stamina (gasto ou regeneraÃ§Ã£o) e a UI.
	
	@param state boolean - True se estÃ¡ gastando, False se estÃ¡ regenerando
	@param deltaTime number - VariaÃ§Ã£o de tempo do frame
]]
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

--[[
	Reduz a stamina por um valor fixo imediato (ex: ao pular).
	@param value number - Valor a ser descontado
]]
function Stamina:ChargeByValue(value: number)
	StaminaUI:TweenLastProgress(stamina)
	stamina = math.clamp(stamina - value, 0, 100)
end

--[[
	Ativa ou desativa o modo de corrida.
	@param state boolean - Estado desejado da corrida
]]
function Stamina:Sprint(state: boolean)
	if exhausted then
		return
	end

	local character = localPlayer.Character
	if not character then return end

	-- Goleiros nÃ£o usam este sistema de corrida
	if character:FindFirstChild("KeeperTool") then
		sprinting = false
		return
	end

	local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
	if not humanoid then return end

	if state then
		humanoid.WalkSpeed = SharedAttributes:GetSprintSpeed()
	else
		humanoid.WalkSpeed = SharedAttributes:GetWalkSpeed()
		lastSprintTime = os.clock()
	end

	sprinting = state
end

--[[
	LÃ³gica de pulo controlada pela stamina.
	SÃ³ permite pular se tiver stamina suficiente e nÃ£o estiver segurando a bola.
]]
function Stamina:Jump()
	local character = localPlayer.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
	if not humanoid then return end

	-- NÃ£o pode pular enquanto estÃ¡ no ar
	if humanoid.FloorMaterial == Enum.Material.Air then 
		return
	end

	-- Verifica custo de stamina
	if stamina < JUMP_DECREASE_RATE then
		return
	end

	-- Bloqueia pulo se o jogador estiver com a bola (ForceField ativo nele)
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

	-- Executa o pulo
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	Stamina:ChargeByValue(JUMP_DECREASE_RATE)
end

--// ============================================================================
--// SETOR: ConexÃµes de Input
--// ============================================================================

-- AÃ§Ãµes de Sprint do InputSystem
InputSystem.Actions.Physical.Sprint.Pressed:Connect(function()
	sprintHeld = true
	Stamina:Sprint(sprintHeld)
end)

InputSystem.Actions.Physical.Sprint.Released:Connect(function()
	sprintHeld = false
	Stamina:Sprint(sprintHeld)
end)

-- RequisiÃ§Ãµes de Pulo
UserInputService.JumpRequest:Connect(function()
	if jumpCooldown then 
		return
	end
	jumpCooldown = true

	Stamina:Jump()
	task.wait(0.25) -- Cooldown tÃ©cnico

	jumpCooldown = false
end)

--// ============================================================================
--// SETOR: Loop Principal (Heartbeat)
--// ============================================================================

RunService.Heartbeat:Connect(function(deltaTime)
	local character = localPlayer.Character
	local isMoving = false

	if character then
		-- Desativa corrida se for Goleiro
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
		-- Gastando stamina
		if stamina > 0 then
			Stamina:ChargeStamina(true, deltaTime) 
		else
			Stamina:Sprint(false) -- ExaustÃ£o
			exhausted = true
		end
	else 
		-- Regenerando stamina
		if (os.clock() - lastSprintTime) > REGEN_DELAY then
			if stamina < 100 then
				Stamina:ChargeStamina(false, deltaTime)

				-- Sai do estado de exaustÃ£o se recuperar o mÃ­nimo necessÃ¡rio
				if stamina > RUN_REFRESH then
					exhausted = false

					if sprintHeld then
						Stamina:Sprint(sprintHeld) -- Retoma corrida automaticamente
					end 
				end
			end
		end
	end

	-- Atualiza visual frame a frame
	StaminaUI:TweenProgress(stamina)
end)

return Stamina

