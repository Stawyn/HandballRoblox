--[[
	================================================================================
	MÓDULO: Stamina
	================================================================================
	
	Descrição:
		Sistema de stamina (energia) do jogador.
		Gerencia o consumo de energia ao correr e pular, regeneração e UI.
	
	Dependências:
		- StaminaUI (Visual)
		- SharedAttributes (Valores de velocidade)
		- InputSystem (Entrada de comandos)
	
	Autor: Sistema ABH
	================================================================================
]]

--// ============================================================================
--// SETOR: Serviços
--// ============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// ============================================================================
--// SETOR: Dependências
--// ============================================================================

-- Assumindo caminhos relativos originais para compatibilidade
local StaminaUI = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Implementation"):WaitForChild("StaminaUI"))
local SharedAttributes = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Implementation"):WaitForChild("SharedAttributes"))
local InputSystem = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Implementation"):WaitForChild("InputSystem"))

local Stamina = {}

--// ============================================================================
--// SETOR: Configurações e Constantes
--// ============================================================================

local STAMINA_DURATION = 7 			-- Duração total em segundos se correr sem parar
local DRAIN_RATE = 100 / STAMINA_DURATION
local INCREASE_RATE = 20 			-- Taxa de regeneração por segundo
local JUMP_DECREASE_RATE = 24 		-- Custo de stamina por pulo
local RUN_REFRESH = 15 				-- Stamina necessária para voltar a correr após exaustào
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

-- Inicializa o contexto de input físico
InputSystem.Contexts.Physical.Enabled = true 

-- Configura botào da UI Mobile
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
--// SETOR: Funções Principais
--// ============================================================================

--[[
	Atualiza o valor da stamina (gasto ou regeneração) e a UI.
	
	@param state boolean - True se está gastando, False se está regenerando
	@param deltaTime number - Variação de tempo do frame
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

	-- Goleiros não usam este sistema de corrida
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
	Lógica de pulo controlada pela stamina.
	Só permite pular se tiver stamina suficiente e não estiver segurando a bola.
]]
function Stamina:Jump()
	local character = localPlayer.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
	if not humanoid then return end

	-- não pode pular enquanto está no ar
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
--// SETOR: Conexões de Input
--// ============================================================================

-- Ações de Sprint do InputSystem
InputSystem.Actions.Physical.Sprint.Pressed:Connect(function()
	sprintHeld = true
	Stamina:Sprint(sprintHeld)
end)

InputSystem.Actions.Physical.Sprint.Released:Connect(function()
	sprintHeld = false
	Stamina:Sprint(sprintHeld)
end)

-- Requisições de Pulo
UserInputService.JumpRequest:Connect(function()
	if jumpCooldown then 
		return
	end
	jumpCooldown = true

	Stamina:Jump()
	task.wait(0.25) -- Cooldown técnico

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
			Stamina:Sprint(false) -- Exaustào
			exhausted = true
		end
	else 
		-- Regenerando stamina
		if (os.clock() - lastSprintTime) > REGEN_DELAY then
			if stamina < 100 then
				Stamina:ChargeStamina(false, deltaTime)

				-- Sai do estado de exaustào se recuperar o mínimo necessário
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

