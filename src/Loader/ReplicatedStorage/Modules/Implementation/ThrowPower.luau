--[[
    ================================================================================
    MÓDULO: ThrowPower
    ================================================================================
    Descrição: Cálculo de força de arremesso ajustada.
               Aplica multiplicadores baseados em direção, altura e oponentes.
    
    Algoritmo:
        1. Penaliza arremessos muito altos (yAxis > 20)
        2. Penaliza arremessos de lado (dot product)
        3. Buffar arremessos ao gol com poucos oponentes
    
    Constantes:
        - THROW_BUFF: 1.5x buff base
        - RADIUS: 80 studs para raycast ao gol
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: DEPENDÊNCIAS
--// ============================================================================

local Utils = require("../../Utilities/Utils")

--// ============================================================================
--// SETOR: CONSTANTES
--// ============================================================================

local CORE_FOLDER = workspace:WaitForChild("Core")
local THROW_BUFF = 1.5
local HOME_GLT = CORE_FOLDER:WaitForChild("GLT"):WaitForChild("Home")
local AWAY_GLT = HOME_GLT.Parent.Away
local RADIUS = 80

-- Multiplicadores por altura do arremesso
local THROW_HEIGHT = {
	{ limit = 20, multiplier = 1 },
	{ limit = 35, multiplier = 0.8 },
	{ limit = 50, multiplier = 0.75 },
	{ limit = 60, multiplier = 0.7 },
	{ limit = math.huge, multiplier = 0.6 }
}

--// ============================================================================
--// SETOR: FUNÇÕES AUXILIARES
--// ============================================================================

--- Multiplicador baseado no dot product (direção do arremesso)
-- @param t number - Dot product (-1 a 1)
-- @return number - Multiplicador (0.375 a 1)
local function dotMultiplier(t: number): number
	if t > 0.9 then return 1 end
	
	-- Interpolação linear: P0=(-1, 0.375), P1=(0.9, 1)
	local a = 25/76
	local b = 107/152
	return a * t + b
end

--- Transformação logarítmica para buff de arremesso ao gol
-- @param x number - Número de oponentes
-- @return number - Multiplicador (0.5 a 1.5)
local function throwPowerTransformation(x: number): number
	local int = math.max(0, math.floor(x))
	local t = THROW_BUFF - 0.6 * math.log(int + 1)
	return math.max(0.5, t)
end

--// ============================================================================
--// SETOR: FUNÇÃO PRINCIPAL
--// ============================================================================

--- Calcula força ajustada do arremesso
-- @param mouseDirection vector - Direção do mouse
-- @param mousePosition vector - Posição do mouse
-- @param playerLookDirection vector - Direção que o jogador está olhando
-- @param power number - Força base (0-100)
-- @param playerPosition Vector3 - Posição do jogador
-- @param player Player - Referência ao jogador
-- @return number - Força ajustada
return function(mouseDirection: vector, mousePosition: vector, playerLookDirection: vector, power: number, playerPosition: Vector3, player: Player): number
	local yAxis = math.abs(mouseDirection.y) * 100
	local finalPower = power

	-- Aplica penalidade por altura
	for _, powerInfo in THROW_HEIGHT do
		if yAxis <= powerInfo.limit then
			finalPower *= powerInfo.multiplier
			break
		end
	end
	
	-- Calcula dot product para penalidade de direção
	local mouseDir = vector.normalize(mousePosition * vector.create(1, 0, 1))
	local front = vector.normalize(playerLookDirection * vector.create(1, 0, 1))
	local dot = math.clamp(vector.dot(mouseDir, front), -1, 1)
	
	-- Verifica se está mirando ao gol
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {HOME_GLT, AWAY_GLT}
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	local result = workspace:Raycast(playerPosition, vector.normalize(mouseDirection) * RADIUS, raycastParams)
	
	local multiplier = 1
	if result then
		local opponentsCount = Utils:CountOpponentsInRadius(player, playerPosition)
		multiplier = throwPowerTransformation(opponentsCount)
	end
	
	return finalPower * dotMultiplier(dot) * multiplier
end