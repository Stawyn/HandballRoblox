--[[
	================================================================================
	MÃ“DULO: PowerUI
	================================================================================
	
	DescriÃ§Ã£o:
		Controlador da interface visual de ForÃ§a (Power) para arremessos.
		Gerencia a barra de forÃ§a e a barra de "Fixed Power".
	
	DependÃªncias:
		- Nenhuma (apenas serviÃ§os do Roblox)
	
	Autor: Sistema ABH
	================================================================================
]]

--// ============================================================================
--// SETOR: ServiÃ§os
--// ============================================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

--// ============================================================================
--// SETOR: Constantes e ConfiguraÃ§Ãµes
--// ============================================================================

-- Cores da Barra de ForÃ§a
local COLORS = {
	FULL = Color3.fromRGB(46, 204, 113),    -- Verde Moderno
	MEDIUM = Color3.fromRGB(241, 196, 15),  -- Amarelo Moderno
	CRITICAL = Color3.fromRGB(231, 76, 60), -- Vermelho Moderno
	FIXED_GAIN = Color3.fromRGB(46, 204, 113), -- Ganho de forÃ§a fixa
	FIXED_LOSS = Color3.fromRGB(192, 57, 43)   -- Perda de forÃ§a fixa
}

--// ============================================================================
--// SETOR: ReferÃªncias de UI
--// ============================================================================

local localPlayer = Players.LocalPlayer :: Player
local playerGui = localPlayer.PlayerGui

-- Busca estrutura da UI com timeouts generosos para garantir carregamento
local indicatorUI = playerGui:WaitForChild("Indicator", math.huge)
local mainUI = indicatorUI:WaitForChild("Main")
local powerUI = mainUI:FindFirstChild("Power") :: Frame
local powerIndicatorUI = powerUI:FindFirstChild("Indicator") :: Frame
local powerProgressUI = powerIndicatorUI:FindFirstChild("Progress") :: Frame
local fixedPowerUI = powerProgressUI:FindFirstChild("FixedPower") :: Frame

local PowerUI = {}

--// ============================================================================
--// SETOR: FunÃ§Ãµes Auxiliares de Estilo
--// ============================================================================

--[[
	Retorna a cor baseada na porcentagem de forÃ§a.
]]
local function getPowerColor(percentage)
	if percentage > 0.6 then
		return COLORS.FULL
	elseif percentage > 0.25 then
		return COLORS.MEDIUM
	else
		return COLORS.CRITICAL
	end
end

--[[
	Aplica estilos (bordas, cantos arredondados) aos elementos da UI.
	Executado uma vez na inicializaÃ§Ã£o.
]]
local function stylizePower()
	-- Helper para adicionar UICorner
	local function addCorner(parent, radius)
		local corner = parent:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, radius or 6)
		corner.Parent = parent
	end

	-- Helper para adicionar UIStroke
	local function addStroke(parent, color, thickness)
		local stroke = parent:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
		stroke.Color = color or Color3.fromRGB(60, 60, 70)
		stroke.Thickness = thickness or 2
		stroke.Parent = parent
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

-- Executa a estilizaÃ§Ã£o inicial em thread separada
task.spawn(stylizePower)

--// ============================================================================
--// SETOR: FunÃ§Ãµes PÃºblicas
--// ============================================================================

--[[
	Atualiza visualmente as barras de forÃ§a e forÃ§a fixa.
	Utiliza Lerp para suavizaÃ§Ã£o, ideal para chamadas frequentes (Heartbeat).
	
	@param power number - ForÃ§a atual (0-100)
	@param fixedPower number - ForÃ§a fixa/base (0-100)
]]
function PowerUI:UpdatePower(power: number, fixedPower: number)
	local powerScale = power / 100
	local fixedPowerScale = 1 - (fixedPower / 100)
	local targetColor = getPowerColor(powerScale)

	-- InterpolaÃ§Ã£o Linear (Lerp) para suavizar o movimento da barra principal
	powerProgressUI.Size = powerProgressUI.Size:Lerp(UDim2.fromScale(powerScale, 1), 0.3)
	powerProgressUI.BackgroundColor3 = powerProgressUI.BackgroundColor3:Lerp(targetColor, 0.15)

	-- InterpolaÃ§Ã£o Linear (Lerp) para a barra de forÃ§a fixa
	fixedPowerUI.Size = fixedPowerUI.Size:Lerp(UDim2.fromScale(fixedPowerScale, 1), 0.3)

	local targetFixedColor = if fixedPowerScale < 0 then COLORS.FIXED_GAIN else COLORS.FIXED_LOSS
	fixedPowerUI.BackgroundColor3 = fixedPowerUI.BackgroundColor3:Lerp(targetFixedColor, 0.15)
end

return PowerUI

