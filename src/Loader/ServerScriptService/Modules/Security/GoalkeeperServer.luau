--[[
    ================================================================================
    MÓDULO: GoalkeeperServer
    ================================================================================
    Descrição: Valida ações de goleiro no servidor.
               Implementa cooldown server-side e validação de time.
    
    Funcionalidades:
        - Valida se jogador é realmente goleiro
        - Cooldown server-side para saves
        - Log de tentativas suspeitas
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: SERVIÇOS E DEPENDÊNCIAS
--// ============================================================================

local Players = game:GetService("Players")

--// ============================================================================
--// SETOR: CONSTANTES
--// ============================================================================

local SERVER_SAVE_COOLDOWN = 1.5 -- segundos entre saves
local SERVER_MAX_SAVE_DIST = 12  -- distância máxima para intercepção (studs)

--// ============================================================================
--// SETOR: MÓDULO
--// ============================================================================

local GoalkeeperServer = {}

--// ============================================================================
--// SETOR: FUNÇÕES PÚBLICAS
--// ============================================================================

--- Verifica se um jogador é goleiro
function GoalkeeperServer:IsGoalkeeper(player: Player): boolean
    if not player or not player.Team then
        return false
    end
    return player.Team.Name:find("Goalkeeper") ~= nil
end

--- Valida se o goleiro pode fazer um save (cooldown)
function GoalkeeperServer:CanSave(player: Player): boolean
    -- Verificar se é goleiro
    if not self:IsGoalkeeper(player) then
        warn("[AntiHack] Non-GK tried save:", player.Name)
        return false
    end
    
    -- Verificar cooldown server-side
    local lastSave = player:GetAttribute("LastSaveTime") or 0
    if tick() - lastSave < SERVER_SAVE_COOLDOWN then
        return false
    end
    
    return true
end

--- Registra um save válido
function GoalkeeperServer:RegisterSave(player: Player)
    player:SetAttribute("LastSaveTime", tick())
end

--- Verifica distância máxima para intercepção
function GoalkeeperServer:ValidateSaveDistance(player: Player, ballPosition: Vector3): boolean
    local character = player.Character
    if not character then return false end
    
    local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then return false end
    
    local distance = (hrp.Position - ballPosition).Magnitude
    if distance > SERVER_MAX_SAVE_DIST then
        warn("[AntiHack] GK save too far:", player.Name, distance)
        return false
    end
    
    return true
end

--- Valida e processa um pedido de save completo
function GoalkeeperServer:ProcessSaveRequest(player: Player, ballPosition: Vector3?): boolean
    -- 1. Verificar se é goleiro
    if not self:IsGoalkeeper(player) then
        return false
    end
    
    -- 2. Verificar cooldown
    if not self:CanSave(player) then
        return false
    end
    
    -- 3. Verificar distância (opcional, apenas se ballPosition fornecido)
    if ballPosition and not self:ValidateSaveDistance(player, ballPosition) then
        return false
    end
    
    -- 4. Registrar save
    self:RegisterSave(player)
    
    return true
end

--- Obtém constantes para uso externo
function GoalkeeperServer:GetCooldown(): number
    return SERVER_SAVE_COOLDOWN
end

function GoalkeeperServer:GetMaxDistance(): number
    return SERVER_MAX_SAVE_DIST
end

return GoalkeeperServer
