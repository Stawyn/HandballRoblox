--[[
    ================================================================================
    MÓDULO: PowerUI
    ================================================================================
    Descrição: Interface de força de arremesso - barra de progresso visual.
               Mostra força atual e força ajustada após multiplicadores.
    
    Funcionalidades:
        - Barra de força com cores dinâmicas
        - Indicador de força ajustada (fixedPower)
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

local TWEEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quart)

local COLORS = {
	FULL = Color3.fromRGB(46, 204, 113),      -- Verde moderno
	MEDIUM = Color3.fromRGB(241, 196, 15),    -- Amarelo moderno
	CRITICAL = Color3.fromRGB(231, 76, 60),   -- Vermelho moderno
	FIXED_GAIN = Color3.fromRGB(46, 204, 113),
	FIXED_LOSS = Color3.fromRGB(192, 57, 43)
}

--// ============================================================================
--// SETOR: REFERÊNCIAS
--// ============================================================================

local localPlayer = Players.LocalPlayer :: Player
local playerGui = localPlayer.PlayerGui
local indicatorUI = playerGui:WaitForChild("Indicator", math.huge)
local mainUI = indicatorUI:WaitForChild("Main")
local powerUI = mainUI:FindFirstChild("Power") :: Frame
local powerIndicatorUI = powerUI:FindFirstChild("Indicator") :: Frame
local powerProgressUI = powerIndicatorUI:FindFirstChild("Progress") :: Frame
local fixedPowerUI = powerProgressUI:FindFirstChild("FixedPower") :: Frame

--// ============================================================================
--// SETOR: MÓDULO
--// ============================================================================

local PowerUI = {}

--// ============================================================================
--// SETOR: FUNÇÕES AUXILIARES
--// ============================================================================

--- Retorna cor baseada na porcentagem de força
local function getPowerColor(percentage: number): Color3
	if percentage > 0.6 then
		return COLORS.FULL
	elseif percentage > 0.25 then
		return COLORS.MEDIUM
	else
		return COLORS.CRITICAL
	end
end

--- Estiliza a UI de força
local function stylizePower()
	local function addCorner(parent, radius)
		local corner = parent:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, radius or 6)
		corner.Parent = parent
	end

	if powerUI then
		powerUI.BackgroundTransparency = 1
	end

	if powerIndicatorUI then
		powerIndicatorUI.BackgroundColor3 = Color3.fromRGB(242, 246, 250)
		powerIndicatorUI.BackgroundTransparency = 0
	end

	if powerProgressUI then
		addCorner(powerProgressUI, 4)
	end
end
task.spawn(stylizePower)

--// ============================================================================
--// SETOR: API PÚBLICA
--// ============================================================================

--- Atualiza a UI de força
-- @param power number - Força atual (0-100)
-- @param fixedPower number - Força ajustada após multiplicadores
function PowerUI:UpdatePower(power: number, fixedPower: number)
	local powerScale = power / 100
	local fixedPowerScale = 1 - (fixedPower / 100)
	local targetColor = getPowerColor(powerScale)

	-- Atualiza barra de força
	powerProgressUI.Size = powerProgressUI.Size:Lerp(UDim2.fromScale(powerScale, 1), 0.3)
	powerProgressUI.BackgroundColor3 = powerProgressUI.BackgroundColor3:Lerp(targetColor, 0.15)

	-- Atualiza indicador de força ajustada
	fixedPowerUI.Size = fixedPowerUI.Size:Lerp(UDim2.fromScale(fixedPowerScale, 1), 0.3)

	local targetFixedColor = if fixedPowerScale < 0 then COLORS.FIXED_GAIN else COLORS.FIXED_LOSS
	fixedPowerUI.BackgroundColor3 = fixedPowerUI.BackgroundColor3:Lerp(targetFixedColor, 0.15)
end

return PowerUI
