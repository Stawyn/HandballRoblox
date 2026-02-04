--[[
    ================================================================================
    MÓDULO: Collisions
    ================================================================================
    Descrição: Configuração de grupos de colisão do jogo ABH.
               Define quais objetos colidem entre si.
    
    Grupos de Colisão:
        - ABHBall: Bola do jogo
        - Player: Jogadores de linha
        - Goalkeeper: Goleiros
        - AreaCollision: Áreas do campo (GoalArea, etc.)
        - Antiplayer: Zonas anti-camping
    
    Regras:
        - Bola NÃO colide com jogadores (passa através)
        - Bola NÃO colide com áreas
        - Jogadores colidem com áreas APENAS durante partida
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: SERVIÇOS
--// ============================================================================

local PhysicsService = game:GetService("PhysicsService")
local Teams = game:GetService("Teams")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Janitor = require("../../../ReplicatedStorage/Utilities/Janitor")

--// ============================================================================
--// SETOR: REFERÊNCIAS
--// ============================================================================

local MATCH_VALUE = workspace:WaitForChild("Core"):WaitForChild("Data"):WaitForChild("Match") :: BoolValue

--// ============================================================================
--// SETOR: CONSTANTES DE GRUPOS DE COLISÃO
--// ============================================================================

local DISPLACEMENT_OFFSET = 5

local BALL_COLLISION = "ABHBall"
local PLAYER_COLLISION = "Player"
local GOALKEEPER_COLLISION = "Goalkeeper"
local AREA_COLLISION = "AreaCollision"
local ANTI_CAMP_COLLISION = "Antiplayer"

--// ============================================================================
--// SETOR: REGISTRO DE GRUPOS
--// ============================================================================

PhysicsService:RegisterCollisionGroup(BALL_COLLISION)
PhysicsService:RegisterCollisionGroup(PLAYER_COLLISION)
PhysicsService:RegisterCollisionGroup(GOALKEEPER_COLLISION)
PhysicsService:RegisterCollisionGroup(AREA_COLLISION)
PhysicsService:RegisterCollisionGroup(ANTI_CAMP_COLLISION)

--// ============================================================================
--// SETOR: CONFIGURAÇÃO DE COLISÕES
--// ============================================================================

-- Bola não colide com nada exceto chão/paredes
PhysicsService:CollisionGroupSetCollidable(ANTI_CAMP_COLLISION, BALL_COLLISION, false)
PhysicsService:CollisionGroupSetCollidable(BALL_COLLISION, AREA_COLLISION, false)
PhysicsService:CollisionGroupSetCollidable(BALL_COLLISION, PLAYER_COLLISION, false)
PhysicsService:CollisionGroupSetCollidable(BALL_COLLISION, GOALKEEPER_COLLISION, false)

-- Goleiros não colidem com áreas
PhysicsService:CollisionGroupSetCollidable(AREA_COLLISION, GOALKEEPER_COLLISION, false)

--// ============================================================================
--// SETOR: COLISÃO DINÂMICA (PARTIDA)
--// ============================================================================

-- Jogadores colidem com áreas APENAS durante partida ativa
PhysicsService:CollisionGroupSetCollidable(AREA_COLLISION, PLAYER_COLLISION, MATCH_VALUE.Value)

MATCH_VALUE:GetPropertyChangedSignal("Value"):Connect(function()
	PhysicsService:CollisionGroupSetCollidable(AREA_COLLISION, PLAYER_COLLISION, MATCH_VALUE.Value)
end)

return {}