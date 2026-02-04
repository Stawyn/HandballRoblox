--[[
	================================================================================
	MÓDULO: StaminaUI
	================================================================================
	
	Descrição:
		Controlador da interface visual de Stamina.
		Gerencia as barras de progresso e mudanças de cor baseadas no nível de energia.
	
	Dependências:
		- Nenhuma (apenas serviços do Roblox)
	
	Autor: Sistema ABH
	================================================================================
]]

--// ============================================================================
--// SETOR: Serviços
--// ============================================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

--// ============================================================================
--// SETOR: Constantes e Configurações
--// ============================================================================

-- Configurações de Animação
local TWEEN_INFO_MAIN = TweenInfo.new(0.75, Enum.EasingStyle.Quart)
local TWEEN_INFO_BAR = TweenInfo.new(0.25, Enum.EasingStyle.Quart)

-- Cores da Barra de Stamina
local COLORS = {
	FULL = Color3.fromRGB(46, 204, 113),    -- Verde Moderno (> 60%)
	MEDIUM = Color3.fromRGB(241, 196, 15),  -- Amarelo Moderno (> 25%)
	CRITICAL = Color3.fromRGB(231, 76, 60), -- Vermelho Moderno (< 25%)
}

--// ============================================================================
--// SETOR: Referências de UI
--// ============================================================================

local localPlayer = Players.LocalPlayer :: Player
local playerGui = localPlayer.PlayerGui
local staminaFrame = playerGui:WaitForChild("Indicator").Main.Stamina.Indicator

-- Referências diretas à s barras (LastProgress e Progress)
local staminaLastProgressUI = staminaFrame:FindFirstChild("LastProgress") :: Frame
local staminaProgressUI = staminaFrame:FindFirstChild("Progress") :: Frame

local StaminaUI = {}

--// ============================================================================
--// SETOR: Funções Auxiliares
--// ============================================================================

--[[
	Retorna a cor apropriada baseada na porcentagem de stamina.
	
	@param percentage number - Valor entre 0 e 1
	@return Color3
]]
local function getStaminaColor(percentage)
	if percentage > 0.6 then
		return COLORS.FULL
	elseif percentage > 0.25 then
		return COLORS.MEDIUM
	else
		return COLORS.CRITICAL
	end
end

--// ============================================================================
--// SETOR: Funções Públicas
--// ============================================================================

--[[
	Anima a barra de "Last Progress" (barra secundária/fundo).
	
	@param stamina number - Valor atual de stamina (0-100)
]]
function StaminaUI:TweenLastProgress(stamina: number)
	TweenService:Create(staminaLastProgressUI, TWEEN_INFO_MAIN, {
		Size = UDim2.fromScale(stamina / 100, 1)
	}):Play()
end

--[[
	Anima a barra principal de progresso e atualiza sua cor.
	
	@param stamina number - Valor atual de stamina (0-100)
]]
function StaminaUI:TweenProgress(stamina: number)
	local percentage = stamina / 100
	local targetColor = getStaminaColor(percentage)

	TweenService:Create(staminaProgressUI, TWEEN_INFO_BAR, {
		Size = UDim2.fromScale(percentage, 1),
		BackgroundColor3 = targetColor
	}):Play()
end

return StaminaUI

