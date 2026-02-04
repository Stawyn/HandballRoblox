--[[
	================================================================================
	MÃ“DULO: ThrowTool (Ferramenta de Arremesso)
	================================================================================
	
	DescriÃ§Ã£o:
		MÃ³dulo cliente que gerencia a ferramenta de arremesso (ThrowTool):
		- Carregamento de poder
		- AnimaÃ§Ãµes de carregamento e arremesso
		- Fake throw (finta)
		- Sistema de tackle
		- IntegraÃ§Ã£o com PowerUI
	
	Autor: Sistema ABH
	Refatorado: RemoÃ§Ã£o de funÃ§Ã£o duplicada, documentaÃ§Ã£o em PT-BR
	================================================================================
]]

--// ============================================================================
--// SETOR: ServiÃ§os do Roblox
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

local TIME_TILL_POWER_REACHES_FULL = 0.5  -- Tempo para atingir 100% de forÃ§a
local GAIN_RATE = 100 / TIME_TILL_POWER_REACHES_FULL  -- Taxa de ganho de forÃ§a/segundo

--// ============================================================================
--// SETOR: Estado Global
--// ============================================================================

local charging = false  -- Se estÃ¡ carregando o arremesso
local localPlayer = Players.LocalPlayer :: Player

--// ============================================================================
--// SETOR: FunÃ§Ãµes Auxiliares
--// ============================================================================

--- Verifica se a ThrowTool estÃ¡ equipada (usa mÃ³dulo centralizado)
-- @return boolean - true se a ferramenta estÃ¡ equipada
local function isToolEquipped(): boolean
	return ToolUtils.isToolEquipped(localPlayer, "ThrowTool")
end

--// ============================================================================
--// SETOR: API PÃºblica
--// ============================================================================

--- Retorna se o jogador estÃ¡ carregando um arremesso
function ThrowTool:GetCharging(): boolean
	return charging
end

--// ============================================================================
--// SETOR: InicializaÃ§Ã£o da Ferramenta
--// ============================================================================

--- Inicializa a ferramenta de arremesso
-- @param tool Tool - InstÃ¢ncia da ferramenta
function ThrowTool:Initialize(tool: Tool)	
	-- Estado local da ferramenta
	local power = 0
	local uiCooldown = false
	local switchHandsCooldown = false
	local tackleCooldown = false
	local chargingThrowAnimation: AnimationTrack? = nil

	-- Maids para gerenciamento de conexÃµes
	local throwMaid = Maid.new()
	local keybindMaid = Maid.new()
	local powerMaid = Maid.new()

	--// ----------------------------------------------------------------
	--// SUB-SETOR: FunÃ§Ãµes Internas
	--// ----------------------------------------------------------------

	--- Define estado de carregamento e gerencia animaÃ§Ã£o
	local function setCharging(state: boolean)
		local character = localPlayer.Character
		if not character then
			charging = state
			return
		end

		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		local animator = humanoid:WaitForChild("Animator") :: Animator

		if not state then
			-- Para animaÃ§Ã£o de carregamento
			if chargingThrowAnimation then
				chargingThrowAnimation:Stop()
			end
		else
			-- Inicia animaÃ§Ã£o de carregamento baseada na mÃ£o
			local currentHand = localPlayer:GetAttribute("CurrentHand")
			local animationToLoad = if currentHand == "R" 
				then Animations.RHandChargeThrow
				else Animations.LHandChargeThrow

			chargingThrowAnimation = animator:LoadAnimation(animationToLoad)
			chargingThrowAnimation:Play()
		end

		charging = state
	end

	--- Reproduz animaÃ§Ã£o de arremesso
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

		-- ObtÃ©m direÃ§Ã£o do mouse/cÃ¢mera
		local mousePosition = localPlayer:GetMouse().Hit.LookVector
		local mouseDirection = localPlayer:GetMouse().UnitRay.Direction

		-- Mobile nÃ£o tem mouse, usa direÃ§Ã£o da cÃ¢mera
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
	--// SUB-SETOR: ConexÃ£o de Equipar
	--// ----------------------------------------------------------------

	tool.Equipped:Connect(function()
		-- Habilita contexto de input
		InputSystem.Contexts["Throw Tool"].Enabled = true 

		-- ConexÃ£o: Iniciar carregamento
		keybindMaid:GiveTask(InputSystem.Actions["Throw Tool"].Throw.Pressed:Connect(function()
			setCharging(true)
			uiCooldown = true
		end))

		-- ConexÃ£o: Soltar = arremessar
		keybindMaid:GiveTask(InputSystem.Actions["Throw Tool"].Throw.Released:Connect(function()
			if not uiCooldown then 
				return
			end

			handleThrow()
			setCharging(false)
			power = 0
			uiCooldown = false
		end))

		-- ConexÃ£o: Tackle
		keybindMaid:GiveTask(InputSystem.Actions["Throw Tool"].Tackle.Pressed:Connect(function()
			-- NÃ£o pode tacklear se tem bola
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

		-- ConexÃ£o: Fake Throw (finta)
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
	--// SUB-SETOR: ConexÃ£o de Desequipar
	--// ----------------------------------------------------------------

	tool.Unequipped:Connect(function()
		-- Desabilita contexto de input
		InputSystem.Contexts["Throw Tool"].Enabled = false

		-- Limpa conexÃµes
		throwMaid:DoCleaning()
		keybindMaid:DoCleaning()
		charging = false

		-- Para animaÃ§Ã£o se existir
		if chargingThrowAnimation then
			chargingThrowAnimation:Stop()
		end

		-- Solta bola se tiver
		if localPlayer.Character and localPlayer.Character:FindFirstChild("BallOwnership") then
			ClientNetwork.BallEvents:DropRequest()
		end
	end)

	--// ----------------------------------------------------------------
	--// SUB-SETOR: ConexÃ£o de DestruiÃ§Ã£o
	--// ----------------------------------------------------------------

	tool.Destroying:Connect(function()
		throwMaid:DoCleaning()
		keybindMaid:DoCleaning()
		powerMaid:DoCleaning()
	end)

	--// ----------------------------------------------------------------
	--// SUB-SETOR: Loop de AtualizaÃ§Ã£o de Poder
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
--// SETOR: Retorno do MÃ³dulo
--// ============================================================================

return ThrowTool

