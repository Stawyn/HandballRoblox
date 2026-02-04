--[[
    ================================================================================
    MÓDULO: StaminaUI
    ================================================================================
    Descrição: Interface de stamina do jogador - barra de energia visual.
               Mostra progresso atual e progresso anterior para efeito de "dano".
    
    Funcionalidades:
        - Barra de stamina com cores dinâmicas
        - Barra de "último progresso" para efeito visual
        - Cores: Verde (>60%), Amarelo (25-60%), Vermelho (<25%)
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: SERVIÇOS E DEPENDÊNCIAS
--// ============================================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

--// ============================================================================
--// SETOR: CONSTANTES
--// ============================================================================

local TWEEN_INFO = TweenInfo.new(0.75, Enum.EasingStyle.Quart)
local STAMINA_TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quart)

local COLORS = {
	FULL = Color3.fromRGB(46, 204, 113),      -- Verde moderno
	MEDIUM = Color3.fromRGB(241, 196, 15),    -- Amarelo moderno
	CRITICAL = Color3.fromRGB(231, 76, 60),   -- Vermelho moderno
}

--// ============================================================================
--// SETOR: REFERÊNCIAS
--// ============================================================================

local localPlayer = Players.LocalPlayer :: Player
local playerGui = localPlayer.PlayerGui
local staminaFrame = playerGui:WaitForChild("Indicator").Main.Stamina.Indicator
local staminaLastProgressUI = staminaFrame:FindFirstChild("LastProgress") :: Frame
local staminaProgressUI = staminaFrame:FindFirstChild("Progress") :: Frame

--// ============================================================================
--// SETOR: MÓDULO
--// ============================================================================

local StaminaUI = {}

--// ============================================================================
--// SETOR: FUNÇÕES AUXILIARES
--// ============================================================================

--- Retorna cor baseada na porcentagem de stamina
local function getStaminaColor(percentage: number): Color3
	if percentage > 0.6 then
		return COLORS.FULL
	elseif percentage > 0.25 then
		return COLORS.MEDIUM
	else
		return COLORS.CRITICAL
	end
end

--// ============================================================================
--// SETOR: API PÚBLICA
--// ============================================================================

--- Atualiza barra de último progresso (efeito de dano)
-- @param stamina number - Stamina atual (0-100)
function StaminaUI:TweenLastProgress(stamina: number)
	TweenService:Create(staminaLastProgressUI, TWEEN_INFO, {
		Size = UDim2.fromScale(stamina / 100, 1)
	}):Play()
end

--- Atualiza barra de progresso atual
-- @param stamina number - Stamina atual (0-100)
function StaminaUI:TweenProgress(stamina: number)
	local percentage = stamina / 100
	local targetColor = getStaminaColor(percentage)

	TweenService:Create(staminaProgressUI, STAMINA_TWEEN_INFO, {
		Size = UDim2.fromScale(percentage, 1),
		BackgroundColor3 = targetColor
	}):Play()
end

return StaminaUI
