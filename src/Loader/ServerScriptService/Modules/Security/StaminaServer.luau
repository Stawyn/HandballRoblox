--[[
    ================================================================================
    MÓDULO: StaminaServer
    ================================================================================
    Descrição: Controla stamina de todos os jogadores server-side.
               Cliente apenas envia pedidos de sprint, servidor valida e aplica.
    
    Funcionalidades:
        - Rastreia stamina de cada jogador no servidor
        - Valida pedidos de sprint do cliente
        - Aplica WalkSpeed diretamente no servidor
        - Drena/regenera stamina automaticamente
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: SERVIÇOS E DEPENDÊNCIAS
--// ============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedAttributes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Implementation"):WaitForChild("SharedAttributes"))

--// ============================================================================
--// SETOR: CONSTANTES
--// ============================================================================

local DRAIN_RATE = 10 -- stamina por segundo ao sprintar
local REGEN_RATE = 5  -- stamina por segundo em repouso
local MAX_STAMINA = 100
local UPDATE_INTERVAL = 0.1 -- segundos

--// ============================================================================
--// SETOR: ESTADO
--// ============================================================================

local playerStamina = {} :: {[number]: number}

--// ============================================================================
--// SETOR: MÓDULO
--// ============================================================================

local StaminaServer = {}

--// ============================================================================
--// SETOR: FUNÇÕES PÚBLICAS
--// ============================================================================

--- Obtém a stamina atual de um jogador
function StaminaServer:GetStamina(player: Player): number
    return playerStamina[player.UserId] or MAX_STAMINA
end

--- Define a stamina de um jogador
function StaminaServer:SetStamina(player: Player, value: number)
    playerStamina[player.UserId] = math.clamp(value, 0, MAX_STAMINA)
end

--- Verifica se jogador pode sprintar
function StaminaServer:CanSprint(player: Player): boolean
    local stamina = playerStamina[player.UserId]
    return stamina and stamina > 0
end

--// ============================================================================
--// SETOR: CONEXÕES DE JOGADORES
--// ============================================================================

Players.PlayerAdded:Connect(function(player)
    playerStamina[player.UserId] = MAX_STAMINA
end)

Players.PlayerRemoving:Connect(function(player)
    playerStamina[player.UserId] = nil
end)

-- Inicializar jogadores já presentes
for _, player in Players:GetPlayers() do
    playerStamina[player.UserId] = MAX_STAMINA
end

--// ============================================================================
--// SETOR: EVENTO DE SPRINT
--// ============================================================================

local NETWORK_FOLDER = ReplicatedStorage:WaitForChild("Network")
local STAMINA_EVENT = NETWORK_FOLDER:FindFirstChild("StaminaEvent") :: RemoteEvent?

if STAMINA_EVENT then
    STAMINA_EVENT.OnServerEvent:Connect(function(player, action)
        local userId = player.UserId
        local stamina = playerStamina[userId]
        if not stamina then return end
        
        local character = player.Character
        local humanoid = character and character:FindFirstChild("Humanoid") :: Humanoid?
        if not humanoid then return end
        
        if action == "StartSprint" then
            if stamina <= 0 then 
                -- Forçar velocidade normal se sem stamina
                humanoid.WalkSpeed = SharedAttributes:GetWalkSpeed()
                return 
            end
            humanoid.WalkSpeed = SharedAttributes:GetSprintSpeed()
            player:SetAttribute("Sprinting", true)
        elseif action == "StopSprint" then
            humanoid.WalkSpeed = SharedAttributes:GetWalkSpeed()
            player:SetAttribute("Sprinting", nil)
        end
    end)
end

--// ============================================================================
--// SETOR: LOOP DE ATUALIZAÇÃO
--// ============================================================================

task.spawn(function()
    while true do
        task.wait(UPDATE_INTERVAL)
        
        for _, player in Players:GetPlayers() do
            local userId = player.UserId
            if not playerStamina[userId] then continue end
            
            local character = player.Character
            local humanoid = character and character:FindFirstChild("Humanoid") :: Humanoid?
            
            if player:GetAttribute("Sprinting") then
                -- Drenar stamina
                playerStamina[userId] = math.max(0, playerStamina[userId] - DRAIN_RATE * UPDATE_INTERVAL)
                
                -- Se acabou, forçar parar sprint
                if playerStamina[userId] <= 0 then
                    if humanoid then
                        humanoid.WalkSpeed = SharedAttributes:GetWalkSpeed()
                    end
                    player:SetAttribute("Sprinting", nil)
                end
            else
                -- Regenerar stamina
                playerStamina[userId] = math.min(MAX_STAMINA, playerStamina[userId] + REGEN_RATE * UPDATE_INTERVAL)
            end
        end
    end
end)

return StaminaServer
