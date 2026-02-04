--[[
	================================================================================
	MÓDULO: SwitchHands
	================================================================================
	
	Descrição:
		Controla a troca de mão (Direita/Esquerda) para segurar a bola.
		Sincroniza com servidor e atualiza indicador visual.
	
	Dependências:
		- ClientNetwork (Sincronização)
		- InputSystem
		- ThrowTool (Verificação de estado)
	
	Autor: Sistema ABH
	================================================================================
]]

--// ============================================================================
--// SETOR: Serviços
--// SETOR: Serviços
--// ============================================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

--// ============================================================================
--// SETOR: Dependências
--// ============================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Espera o Loader terminar
ReplicatedStorage:WaitForChild("LoaderReady")

local Modules = ReplicatedStorage:WaitForChild("Modules")

local InputSystem = require(Modules:WaitForChild("Implementation"):WaitForChild("InputSystem"))
local ClientNetwork = require(Modules:WaitForChild("Implementation"):WaitForChild("ClientNetwork"))
local ThrowTool = require(Modules:WaitForChild("Systems"):WaitForChild("ToolsController"):WaitForChild("ThrowTool"))

--// ============================================================================
--// SETOR: Estado
--// ============================================================================

local localPlayer = Players.LocalPlayer :: Player
local playerGui = localPlayer.PlayerGui
local cooldown = false

local handsIndicator = playerGui:WaitForChild("Indicator"):WaitForChild("Arm")

-- Ativa contexto de inputs de mãos
InputSystem.Contexts.Hands.Enabled = true

--// ============================================================================
--// SETOR: Interface
--// ============================================================================

--[[
	Atualiza o indicador visual da mão atual.
	Chamado quando o atributo "CurrentHand" muda no jogador.
]]
function onArmChanged()
	handsIndicator.Text = localPlayer:GetAttribute("CurrentHand")
	handsIndicator.TextColor3 = Color3.fromRGB(15, 23, 42) -- Escuro (Flash)

	-- Efeito de flash branco
	TweenService:Create(handsIndicator, TweenInfo.new(0.5), {
		TextColor3 = Color3.fromRGB(255, 255, 255)
	}):Play()
end

--// ============================================================================
--// SETOR: Conexões
--// ============================================================================

-- Trata o input de troca de mão
InputSystem.Actions.Hands["Switch Hand"].Pressed:Connect(function()
	if cooldown then
		return
	end

	-- não pode trocar de mão enquanto carrega o arremesso
	if ThrowTool:GetCharging() == true then
		return
	end

	cooldown = true

	ClientNetwork.SwitchHandsEvent:SwitchRequest()
	task.wait(0.5) -- Cooldown fixo

	cooldown = false
end)

-- Inicializa e conecta listener do atributo
coroutine.wrap(onArmChanged)()
localPlayer:GetAttributeChangedSignal("CurrentHand"):Connect(onArmChanged)

return {}

