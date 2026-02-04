--[[
    ================================================================================
    MÓDULO: SwitchHands
    ================================================================================
    Descrição: Sistema de troca de mão dominante (L/R) do jogador.
               Controla qual mão o jogador usa para segurar/arremessar a bola.
    
    Funcionalidades:
        - Input "Switch Hand" para alternar entre L/R
        - Cooldown de 0.5s entre trocas
        - Atualização visual do indicador
        - Bloqueio durante carregamento de arremesso
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: SERVIÇOS E DEPENDÊNCIAS
--// ============================================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local InputSystem = require("../Implementation/InputSystem")
local ClientNetwork = require("../Implementation/ClientNetwork")
local ThrowTool = require("./ToolsController/ThrowTool")

--// ============================================================================
--// SETOR: REFERÊNCIAS E ESTADO
--// ============================================================================

local localPlayer = Players.LocalPlayer :: Player
local playerGui = localPlayer.PlayerGui
local handsIndicator = playerGui:WaitForChild("Indicator"):WaitForChild("Arm")

local cooldown = false

--// ============================================================================
--// SETOR: INICIALIZAÇÃO
--// ============================================================================

InputSystem.Contexts.Hands.Enabled = true

--// ============================================================================
--// SETOR: HANDLERS DE INPUT
--// ============================================================================

--- Callback de troca de mão
InputSystem.Actions.Hands["Switch Hand"].Pressed:Connect(function()
	-- Verifica cooldown
	if cooldown then return end
	
	-- Bloqueia durante charge
	if ThrowTool:GetCharging() == true then return end
	
	cooldown = true
	ClientNetwork.SwitchHandsEvent:SwitchRequest()
	task.wait(0.5)
	cooldown = false
end)

--// ============================================================================
--// SETOR: ATUALIZAÇÃO VISUAL
--// ============================================================================

--- Atualiza indicador visual da mão
local function onArmChanged()
	handsIndicator.Text = localPlayer:GetAttribute("CurrentHand")
	handsIndicator.TextColor3 = Color3.fromRGB(15, 23, 42)
	TweenService:Create(handsIndicator, TweenInfo.new(0.5), {
		TextColor3 = Color3.fromRGB(255, 255, 255)
	}):Play()
end

-- Inicializa e conecta evento
coroutine.wrap(onArmChanged)()
localPlayer:GetAttributeChangedSignal("CurrentHand"):Connect(onArmChanged)

return {}