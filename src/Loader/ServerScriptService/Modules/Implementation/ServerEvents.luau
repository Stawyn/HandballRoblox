--[[
    ================================================================================
    MODULO: ServerEvents
    ================================================================================
    Descricao: Sinais de servidor para comunicacao entre modulos.
               Centraliza eventos internos do servidor usando Signal.
    
    Sinais Disponiveis:
        - League: Eventos do sistema de partida (START, END_HALF, GOAL, etc.)
    
    Uso:
        ServerEvents.League:Fire("ACTION", ...)
        ServerEvents.League:Connect(function(action, ...) end)
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: DEPENDENCIAS
--// ============================================================================

local Signal = require("../../../ReplicatedStorage/Utilities/Signal")

--// ============================================================================
--// SETOR: MODULO
--// ============================================================================

local ServerEvents = {}

--// ============================================================================
--// SETOR: SINAIS
--// ============================================================================

--- Sinal de eventos da liga/partida
-- Acoes: START, END_HALF, GOAL, RESET, PLAYER_THROW, BALL_TIME_VIOLATION, etc.
ServerEvents.League = Signal.new() :: Signal.Signal<(string, ...unknown)>

return ServerEvents