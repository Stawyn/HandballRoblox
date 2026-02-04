--[[
    ================================================================================
    MÓDULO: ThrowTool
    ================================================================================
    Descrição: Controlador da ferramenta de arremesso - gerencia charging,
               throw, fake throw e tackle.
    
    Funcionalidades:
        - Carregamento de força (0-100%)
        - Arremesso com direção calculada
        - Fake throw (cancela arremesso)
        - Tackle para roubar bola
        - Animações de charge/throw
    
    Constantes:
        - TIME_TILL_POWER_REACHES_FULL: 0.5s para 100%
        - GAIN_RATE: 200%/s de ganho de força
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: SERVIÇOS E DEPENDÊNCIAS
--// ============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")

local ClientNetwork = require("../../Implementation/ClientNetwork")
local Maid = require("../../../Utilities/Maid")
local FixedThrowPower = require("../../../Modules/Implementation/ThrowPower")
local PowerUI = require("../../../Modules/Implementation/PowerUI")
local Animations = require("../../../Utilities/ABHAnimations")
local VectorLib = require("../../../Utilities/Vector")
local InputSystem = require("../../Implementation/InputSystem")

--// ============================================================================
--// SETOR: CONSTANTES
--// ============================================================================

local TIME_TILL_POWER_REACHES_FULL = 0.5
local GAIN_RATE = 100 / TIME_TILL_POWER_REACHES_FULL

--// ============================================================================
--// SETOR: ESTADO
--// ============================================================================

local charging = false
local isThrowing = false
local localPlayer = Players.LocalPlayer :: Player

--// ============================================================================
--// SETOR: MÓDULO
--// ============================================================================

local ThrowTool = {}

local SINK_ACTION_NAME = "ThrowToolSink"

--// ============================================================================
--// SETOR: FUNÇÕES AUXILIARES
--// ============================================================================

--- Define o bloqueio da ferramenta (Backpack e Drop)
local function setToolLock(locked: boolean, tool: Tool?)
	-- Se estiver arremessando (animação), não permite desbloquear via setCharging(false)
	if isThrowing and not locked then return end
	
	-- Bloqueia teclas numéricas 1-0 para impedir troca de ferramenta mantendo a UI visível
	if locked then
		ContextActionService:BindActionAtPriority(SINK_ACTION_NAME, function()
			return Enum.ContextActionResult.Sink
		end, false, 2000, 
		Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, 
		Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six, 
		Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine, 
		Enum.KeyCode.Zero)
	else
		ContextActionService:UnbindAction(SINK_ACTION_NAME)
	end

	-- Define se a ferramenta pode ser dropada
	if tool then
		tool.CanBeDropped = not locked
	elseif localPlayer.Character then
		local equippedTool = localPlayer.Character:FindFirstChild("ThrowTool")
		if equippedTool and equippedTool:IsA("Tool") then
			equippedTool.CanBeDropped = not locked
		end
	end
end

--- Verifica se ThrowTool está equipada
local function CheckToolEquipped(): boolean
	local backpack = localPlayer.Backpack
	local character = localPlayer.Character
	if not character then return false end

	if backpack:FindFirstChild("ThrowTool") then return true end
	if character:FindFirstChild("ThrowTool") then return true end

	return false
end

--- Retorna estado de charging
function ThrowTool:GetCharging(): boolean
	return charging
end

--// ============================================================================
--// SETOR: INICIALIZAÇÃO
--// ============================================================================

--- Inicializa a ferramenta de arremesso
function ThrowTool:Initialize(tool: Tool)	
	local power = 0
	local uiCooldown = false
	local throwMaid = Maid.new()
	local keybindMaid = Maid.new()
	local powerMaid = Maid.new()
	local chargingThrowAnimation: AnimationTrack? = nil
	local tackleCooldown = false

	--- Define estado de charging e animação
	local function setCharging(state: boolean)
		local character = localPlayer.Character
		if not character then
			charging = state
			setToolLock(state, tool)
			return
		end

		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		local animator = humanoid:WaitForChild("Animator") :: Animator

		if not state then
			if chargingThrowAnimation then
				chargingThrowAnimation:Stop()
			end
		else
			local currentHand = localPlayer:GetAttribute("CurrentHand")
			local animationToLoad = if currentHand == "R" 
				then Animations.RHandChargeThrow 
				else Animations.LHandChargeThrow

			chargingThrowAnimation = animator:LoadAnimation(animationToLoad)
			chargingThrowAnimation:Play()
		end


		charging = state
		setToolLock(state, tool)
	end

	--- Toca animação de arremesso
	local function playThrowAnimation(): AnimationTrack?
		local character = localPlayer.Character
		if not character then return nil end

		local currentHand = localPlayer:GetAttribute("CurrentHand")
		local animator = character:WaitForChild("Humanoid"):WaitForChild("Animator") :: Animator

		local throwAnimation = if currentHand == "R" 
			then Animations.RHandThrow 
			else Animations.LHandThrow

		local animationTrack = animator:LoadAnimation(throwAnimation)
		animationTrack:Play()
		return animationTrack
	end

	--- Verifica se ferramenta está equipada
	local function checkToolEquipped(): boolean
		if not localPlayer.Character then return false end
		if not localPlayer.Character:FindFirstChild("ThrowTool") then return false end
		return true
	end

	--- Executa arremesso
	local function handleThrow()
		if not checkToolEquipped() or not charging then return end

		local character = localPlayer.Character
		if not character or not character:FindFirstChild("BallOwnership") then return end

		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart
		local hrpPosition = humanoidRootPart.Position
		local mousePosition = localPlayer:GetMouse().Hit.LookVector
		local mouseDirection = localPlayer:GetMouse().UnitRay.Direction

		-- Mobile usa câmera ao invés de mouse
		if localPlayer:GetAttribute("Mobile") == true then
			mouseDirection = workspace.CurrentCamera.CFrame.LookVector
			mousePosition = mouseDirection
		end

		local direction = humanoidRootPart.CFrame.LookVector
		ClientNetwork.ThrowEvent:Throw(power, {
			humanoidRootPartDirection = vector.create(direction.X, direction.Y, direction.Z),
			mouseDirection = vector.create(mouseDirection.X, mouseDirection.Y, mouseDirection.Z),
			mousePosition = vector.create(mousePosition.X, mousePosition.Y, mousePosition.Z),
			humanoidRootPartPosition = vector.create(hrpPosition.X, hrpPosition.Y, hrpPosition.Z)
		})
		
		isThrowing = true
		local track = playThrowAnimation()
		
		if track then
			task.delay(track.Length, function()
				isThrowing = false
				setToolLock(false, tool)
			end)
		else
			isThrowing = false
			setToolLock(false, tool)
		end
	end

	--// ============================================================================
	--// CONEXÕES
	--// ============================================================================

	tool.Equipped:Connect(function()
		InputSystem.Contexts["Throw Tool"].Enabled = true 

		-- Throw
		keybindMaid:GiveTask(InputSystem.Actions["Throw Tool"].Throw.Pressed:Connect(function()
			setCharging(true)
			uiCooldown = true
		end))
		
		keybindMaid:GiveTask(InputSystem.Actions["Throw Tool"].Throw.Released:Connect(function()
			if not uiCooldown then return end
			handleThrow()
			setCharging(false)
			power = 0
			uiCooldown = false
		end))

		-- Tackle
		keybindMaid:GiveTask(InputSystem.Actions["Throw Tool"].Tackle.Pressed:Connect(function()
			if localPlayer.Character and localPlayer.Character:FindFirstChild("BallOwnership") then return end
			if tackleCooldown or charging then return end

			tackleCooldown = true
			ClientNetwork.TacklingFunction:Tackle()
			tackleCooldown = false
		end))

		-- Fake Throw
		keybindMaid:GiveTask(InputSystem.Actions["Throw Tool"]["Fake Throw"].Pressed:Connect(function()
			if not uiCooldown then return end

			setCharging(false)
			if localPlayer.Character and localPlayer.Character:FindFirstChild("BallOwnership") then
				playThrowAnimation()
			end
			setToolLock(false, tool)
			uiCooldown = false
		end))
	end)

	tool.Unequipped:Connect(function()
		-- Se o jogador tentar remover a tool enquanto segura a bola, forçar re-equip
		if localPlayer.Character and localPlayer.Character:FindFirstChild("BallOwnership") then
			task.defer(function()
				local humanoid = localPlayer.Character:FindFirstChild("Humanoid") :: Humanoid?
				if humanoid and tool.Parent == localPlayer.Backpack then
					humanoid:EquipTool(tool)
				end
			end)
			return
		end
		
		InputSystem.Contexts["Throw Tool"].Enabled = false
		throwMaid:DoCleaning()
		keybindMaid:DoCleaning()
		charging = false
		isThrowing = false
		setToolLock(false, tool)
		
		if chargingThrowAnimation then
			chargingThrowAnimation:Stop()
		end
	end)

	tool.Destroying:Connect(function()
		throwMaid:DoCleaning()
		keybindMaid:DoCleaning()
		powerMaid:DoCleaning()
	end)

	-- Loop de atualização de força
	powerMaid:GiveTask(RunService.Heartbeat:Connect(function(deltaTime)
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

		-- Atualiza UI
		local mouseDirection = VectorLib:Vector3ToVectorLib(localPlayer:GetMouse().UnitRay.Direction)
		local mousePosition = VectorLib:Vector3ToVectorLib(localPlayer:GetMouse().Hit.LookVector)

		local character = localPlayer.Character
		if character and character:FindFirstChild("HumanoidRootPart") then
			local hrp = character.HumanoidRootPart
			local fixedPower = FixedThrowPower(mouseDirection, mousePosition, VectorLib:Vector3ToVectorLib(hrp.CFrame.LookVector), power, hrp.Position, localPlayer)
			PowerUI:UpdatePower(power, fixedPower)
		end
	end))
end

return ThrowTool
