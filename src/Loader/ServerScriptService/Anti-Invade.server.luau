--[[
    ================================================================================
    SCRIPT: Anti-Invade
    ================================================================================
    Descricao: Sistema anti-invasao de quadra - teleporta jogadores do Lobby
               que tentam entrar na area de jogo.
    
    Funcionalidades:
        - Detecta colisao com partes taggeadas "AntiInvade"
        - Teleporta jogadores do time "Lobby" para CrowdSpawn
        - Cooldown para evitar spam de teleporte
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: SERVICOS E DEPENDENCIAS
--// ============================================================================

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

--// ============================================================================
--// SETOR: ESTADO
--// ============================================================================

local teleportedPlayers = {}

--// ============================================================================
--// SETOR: CONEXOES
--// ============================================================================

for _, Part in CollectionService:GetTagged("AntiInvade") do
	Part.Touched:Connect(function(hit)
		local Player = Players:GetPlayerFromCharacter(hit.Parent)

		if Player and Player.Team.Name == "Lobby" and not teleportedPlayers[Player] then	
			local playerCharacter = Player.Character :: Model		
			teleportedPlayers[Player] = true
			playerCharacter:PivotTo(Workspace.CrowdSpawn.SpawnLocation.CFrame + Vector3.new(0, 10, 0))
			task.wait(0.5)
			teleportedPlayers[Player] = false
		end
	end)
end