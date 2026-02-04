--[[
    ================================================================================
    MÓDULO: SharedAttributes
    ================================================================================
    Descrição: Atributos compartilhados do jogo - constantes de velocidade,
               física e configurações globais.
    
    Atributos:
        - WalkSpeed: Velocidade base de caminhada
        - SprintSpeed: Velocidade de sprint (+7)
        - GoalkeeperSpeed: Velocidade do goleiro (10)
        - KDrag: Coeficiente de arrasto (0.7)
        - MaxPing: Ping máximo tolerado (350ms)
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: CONSTANTES
--// ============================================================================

local StarterPlayer = game:GetService("StarterPlayer")
local WALK_SPEED = StarterPlayer.CharacterWalkSpeed

--// ============================================================================
--// SETOR: MÓDULO
--// ============================================================================

local SharedAttributes = {}

--// ============================================================================
--// SETOR: VELOCIDADES
--// ============================================================================

--- Retorna velocidade de caminhada
function SharedAttributes:GetWalkSpeed(): number
	return WALK_SPEED 
end

--- Retorna velocidade de sprint
function SharedAttributes:GetSprintSpeed(): number
	return WALK_SPEED + 7
end

--- Retorna velocidade do goleiro
function SharedAttributes:GetGoalkeeperSpeed(): number
	return 10
end

--- Retorna velocidade do goleiro em modo focado
function SharedAttributes:GetGoalkeeperFocusedSpeed(): number
	return 4
end

--// ============================================================================
--// SETOR: FÍSICA
--// ============================================================================

--- Retorna coeficiente de arrasto
function SharedAttributes:GetKDrag(): number
	return 0.7
end

--// ============================================================================
--// SETOR: REDE
--// ============================================================================

--- Retorna ping máximo tolerado (ms)
function SharedAttributes:MaxPing(): number
	return 350
end

return SharedAttributes