--[[
	================================================================================
	MÓDULO: ThrowTool (Ferramenta de Arremesso)
	================================================================================
	
	Descrição:
		Módulo cliente que gerencia a ferramenta de arremesso (ThrowTool):
		- Carregamento de poder
		- Animações de carregamento e arremesso
		- Fake throw (finta)
		- Sistema de tackle
		- Integração com PowerUI
	
	Autor: Sistema ABH
	Refatorado: Remoção de função duplicada, documentação em PT-BR
	================================================================================
]]

--// ============================================================================
--// SETOR: Serviços do Roblox
--// ============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

--// ============================================================================
--// SETOR: Definição do Módulo
--// ============================================================================

local ThrowTool = {}

--// ============================================================================
--// SETOR: Dependências
--// ============================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Espera o Loader terminar
ReplicatedStorage:WaitForChild("LoaderReady")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Utilities = ReplicatedStorage:WaitForChild("Utilities")

local ClientNetwork = require(Modules:WaitForChild("Implementation"):WaitForChild("ClientNetwork"))
local Maid = require(Utilities:WaitForChild("Maid"))
local FixedThrowPower = require(Modules:WaitForChild("Implementation"):WaitForChild("ThrowPower"))
local PowerUI = require(Modules:WaitForChild("Implementation"):WaitForChild("PowerUI"))
local Animations = require(Utilities:WaitForChild("ABHAnimations"))
local VectorLib = require(Utilities:WaitForChild("Vector"))
local InputSystem = require(Modules:WaitForChild("Implementation"):WaitForChild("InputSystem"))
local ToolUtils = require(Utilities:WaitForChild("ToolUtils"))

--// ============================================================================
--// SETOR: Constantes
--// ============================================================================

local TIME_TILL_POWER_REACHES_FULL = 0.5  -- Tempo para atingir 100% de força
local GAIN_RATE = 100 / TIME_TILL_POWER_REACHES_FULL  -- Taxa de ganho de força/segundo

--// ============================================================================
--// SETOR: Estado Global
--// ============================================================================

local charging = false  -- Se está carregando o arremesso
local localPlayer = Players.LocalPlayer :: Player

--// ============================================================================
--// SETOR: Funções Auxiliares
--// ============================================================================

--- Verifica se a ThrowTool está equipada (usa módulo centralizado)
-- @return boolean - true se a ferramenta está equipada
local function isToolEquipped(): boolean
	return ToolUtils.isToolEquipped(localPlayer, "ThrowTool")
end

--// ============================================================================
--// SETOR: API Pública
--// ============================================================================

--- Retorna se o jogador está carregando um arremesso
function ThrowTool:GetCharging(): boolean
	return charging
end

--// ============================================================================
--// SETOR: Inicialização da Ferramenta
--// ============================================================================

--- Inicializa a ferramenta de arremesso
-- @param tool Tool - Instà¢ncia da ferramenta
function ThrowTool:Initialize(tool: Tool)	
	-- Estado local da ferramenta
	local power = 0
	local uiCooldown = false
	local switchHandsCooldown = false
	local tackleCooldown = false
	local chargingThrowAnimation: AnimationTrack? = nil

	-- Maids para gerenciamento de conexões
	local throwMaid = Maid.new()
	local keybindMaid = Maid.new()
	local powerMaid = Maid.new()

	--// ----------------------------------------------------------------
	--// SUB-SETOR: Funções Internas
	--// ----------------------------------------------------------------

	--- Define estado de carregamento e gerencia animação
	local function setCharging(state: boolean)
		local character = localPlayer.Character
		if not character then
			charging = state
			return
		end

		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		local animator = humanoid:WaitForChild("Animator") :: Animator

		if not state then
			-- Para animação de carregamento
			if chargingThrowAnimation then
				chargingThrowAnimation:Stop()
			end
		else
			-- Inicia animação de carregamento baseada na mão
			local currentHand = localPlayer:GetAttribute("CurrentHand")
			local animationToLoad = if currentHand == "R" 
				then Animations.RHandChargeThrow
				else Animations.LHandChargeThrow

			chargingThrowAnimation = animator:LoadAnimation(animationToLoad)
			chargingThrowAnimation:Play()
		end

		charging = state
	end

	--- Reproduz animação de arremesso
	local function playThrowAnimation()
		local character = localPlayer.Character
		if not character then
			return
		end

		local currentHand = localPlayer:GetAttribute("CurrentHand")
		local animator = character:WaitForChild("Humanoid"):WaitForChild("Animator") :: Animator

		local throwAnimation = if currentHand == "R" 
			then Animations.RHandThrow
			else Animations.LHandThrow

		local animationTrack = animator:LoadAnimation(throwAnimation)
		animationTrack:Play()
	end

	--- Executa o arremesso
	local function handleThrow()
		if not isToolEquipped() then
			return
		end
		if not charging then
			return
		end

		local character = localPlayer.Character
		if not character then
			return
		end

		-- Verifica se tem posse da bola
		if not character:FindFirstChild("BallOwnership") then
			return
		end

		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart
		local hrpPosition = humanoidRootPart.Position

		-- Obtém direção do mouse/cà¢mera
		local mousePosition = localPlayer:GetMouse().Hit.LookVector
		local mouseDirection = localPlayer:GetMouse().UnitRay.Direction

		-- Mobile não tem mouse, usa direção da cà¢mera
		if localPlayer:GetAttribute("Mobile") == true then
			mouseDirection = workspace.CurrentCamera.CFrame.LookVector
			mousePosition = mouseDirection
		end

		local direction = humanoidRootPart.CFrame.LookVector

		-- Envia evento de arremesso para o servidor
		ClientNetwork.ThrowEvent:Throw(power, {
			humanoidRootPartDirection = vector.create(direction.X, direction.Y, direction.Z),
			mouseDirection = vector.create(mouseDirection.X, mouseDirection.Y, mouseDirection.Z),
			mousePosition = vector.create(mousePosition.X, mousePosition.Y, mousePosition.Z),
			humanoidRootPartPosition = vector.create(hrpPosition.X, hrpPosition.Y, hrpPosition.Z)
		})

		playThrowAnimation()
	end

	--// ----------------------------------------------------------------
	--// SUB-SETOR: Conexào de Equipar
	--// ----------------------------------------------------------------

	tool.Equipped:Connect(function()
		-- Habilita contexto de input
		InputSystem.Contexts["Throw Tool"].Enabled = true 

		-- Conexào: Iniciar carregamento
		keybindMaid:GiveTask(InputSystem.Actions["Throw Tool"].Throw.Pressed:Connect(function()
			setCharging(true)
			uiCooldown = true
		end))

		-- Conexào: Soltar = arremessar
		keybindMaid:GiveTask(InputSystem.Actions["Throw Tool"].Throw.Released:Connect(function()
			if not uiCooldown then 
				return
			end

			handleThrow()
			setCharging(false)
			power = 0
			uiCooldown = false
		end))

		-- Conexào: Tackle
		keybindMaid:GiveTask(InputSystem.Actions["Throw Tool"].Tackle.Pressed:Connect(function()
			-- não pode tacklear se tem bola
			if localPlayer.Character and localPlayer.Character:FindFirstChild("BallOwnership") then
				return
			end
			if tackleCooldown then 
				return
			end
			if charging then 
				return
			end

			tackleCooldown = true
			ClientNetwork.TacklingFunction:Tackle()
			tackleCooldown = false
		end))

		-- Conexào: Fake Throw (finta)
		keybindMaid:GiveTask(InputSystem.Actions["Throw Tool"]["Fake Throw"].Pressed:Connect(function()
			if not uiCooldown then
				return
			end

			setCharging(false)
			if localPlayer.Character and localPlayer.Character:FindFirstChild("BallOwnership") then
				playThrowAnimation()
			end
			uiCooldown = false
		end))
	end)

	--// ----------------------------------------------------------------
	--// SUB-SETOR: Conexào de Desequipar
	--// ----------------------------------------------------------------

	tool.Unequipped:Connect(function()
		-- Desabilita contexto de input
		InputSystem.Contexts["Throw Tool"].Enabled = false

		-- Limpa conexões
		throwMaid:DoCleaning()
		keybindMaid:DoCleaning()
		charging = false

		-- Para animação se existir
		if chargingThrowAnimation then
			chargingThrowAnimation:Stop()
		end

		-- Solta bola se tiver
		if localPlayer.Character and localPlayer.Character:FindFirstChild("BallOwnership") then
			ClientNetwork.BallEvents:DropRequest()
		end
	end)

	--// ----------------------------------------------------------------
	--// SUB-SETOR: Conexào de Destruição
	--// ----------------------------------------------------------------

	tool.Destroying:Connect(function()
		throwMaid:DoCleaning()
		keybindMaid:DoCleaning()
		powerMaid:DoCleaning()
	end)

	--// ----------------------------------------------------------------
	--// SUB-SETOR: Loop de Atualização de Poder
	--// ----------------------------------------------------------------

	powerMaid:GiveTask(RunService.Heartbeat:Connect(function(deltaTime)
		-- Atualiza poder se carregando
		if charging then
			if power < 100 then
				power += GAIN_RATE * deltaTime
				power = math.clamp(power, 0, 100)
			end
		else
			if power ~= 0 then
				power = 0
			end
		end

		-- Atualiza UI de poder
		local mouseDirection = VectorLib:Vector3ToVectorLib(localPlayer:GetMouse().UnitRay.Direction)
		local mousePosition = VectorLib:Vector3ToVectorLib(localPlayer:GetMouse().Hit.LookVector)

		local character = localPlayer.Character
		if character and character:FindFirstChild("HumanoidRootPart") then
			local hrp = character.HumanoidRootPart
			local fixedPower = FixedThrowPower(
				mouseDirection, 
				mousePosition, 
				VectorLib:Vector3ToVectorLib(hrp.CFrame.LookVector), 
				power, 
				hrp.Position, 
				localPlayer
			)

			PowerUI:UpdatePower(power, fixedPower)
		end
	end))
end

--// ============================================================================
--// SETOR: Retorno do Módulo
--// ============================================================================

return ThrowTool

