--[[
    ================================================================================
    MÓDULO: TeamUtils
    ================================================================================
    Descrição: Utilitários centralizados para verificação e manipulação de times
               no jogo ABH Handball.
    
    Funcionalidades:
        - isHomePlayer: Verifica se jogador pertence ao time Home
        - isAwayPlayer: Verifica se jogador pertence ao time Away
        - isGoalkeeper: Verifica se jogador é goleiro
        - areOpponents: Verifica se dois jogadores são de times opostos
        - areSameTeam: Verifica se dois jogadores são do mesmo time
        - getTeamSide: Retorna o lado do time ("Home", "Away", "Officials", "Lobby")
        - getOpponentPlayers: Retorna lista de jogadores oponentes
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: SERVIÇOS E DEPENDÊNCIAS
--// ============================================================================

local Teams = game:GetService("Teams")

--// ============================================================================
--// SETOR: CONSTANTES
--// ============================================================================

local TeamUtils = {}

-- Nomes dos times para referência
local HOME_TEAM_NAME = "Home Team"
local HOME_GK_NAME = "-Home Goalkeeper"
local AWAY_TEAM_NAME = "Away Team"
local AWAY_GK_NAME = "-Away Goalkeeper"
local OFFICIALS_NAME = "Officials"
local LOBBY_NAME = "Lobby"

--// ============================================================================
--// SETOR: FUNÇÕES AUXILIARES INTERNAS
--// ============================================================================

--- Obtém o nome do time do jogador de forma segura
-- @param player Player - O jogador a verificar
-- @return string? - Nome do time ou nil se sem time
local function getTeamName(player: Player): string?
	if not player then return nil end
	local team = player.Team
	if not team then return nil end
	return team.Name
end

--// ============================================================================
--// SETOR: FUNÇÕES PÚBLICAS - VERIFICAÇÃO DE TIME
--// ============================================================================

--- Verifica se o jogador pertence ao lado Home (incluindo goleiro)
-- @param player Player - O jogador a verificar
-- @return boolean - true se for do time Home
function TeamUtils.isHomePlayer(player: Player): boolean
	local teamName = getTeamName(player)
	if not teamName then return false end
	return teamName == HOME_TEAM_NAME or teamName == HOME_GK_NAME
end

--- Verifica se o jogador pertence ao lado Away (incluindo goleiro)
-- @param player Player - O jogador a verificar
-- @return boolean - true se for do time Away
function TeamUtils.isAwayPlayer(player: Player): boolean
	local teamName = getTeamName(player)
	if not teamName then return false end
	return teamName == AWAY_TEAM_NAME or teamName == AWAY_GK_NAME
end

--- Verifica se o jogador é um goleiro (Home ou Away)
-- @param player Player - O jogador a verificar
-- @return boolean - true se for goleiro
function TeamUtils.isGoalkeeper(player: Player): boolean
	local teamName = getTeamName(player)
	if not teamName then return false end
	return teamName == HOME_GK_NAME or teamName == AWAY_GK_NAME
end

--- Verifica se o jogador é um árbitro/oficial
-- @param player Player - O jogador a verificar
-- @return boolean - true se for oficial
function TeamUtils.isOfficial(player: Player): boolean
	local teamName = getTeamName(player)
	return teamName == OFFICIALS_NAME
end

--- Verifica se o jogador está no Lobby
-- @param player Player - O jogador a verificar
-- @return boolean - true se estiver no lobby
function TeamUtils.isInLobby(player: Player): boolean
	local teamName = getTeamName(player)
	return teamName == LOBBY_NAME or teamName == nil
end

--- Verifica se o jogador está em jogo (Home ou Away, não Lobby/Officials)
-- @param player Player - O jogador a verificar
-- @return boolean - true se estiver em jogo
function TeamUtils.isInGame(player: Player): boolean
	return TeamUtils.isHomePlayer(player) or TeamUtils.isAwayPlayer(player)
end

--// ============================================================================
--// SETOR: FUNÇÕES PÚBLICAS - COMPARAÇÃO DE TIMES
--// ============================================================================

--- Retorna o lado do time do jogador
-- @param player Player - O jogador a verificar
-- @return string - "Home", "Away", "Officials", "Lobby" ou "Unknown"
function TeamUtils.getTeamSide(player: Player): string
	if TeamUtils.isHomePlayer(player) then
		return "Home"
	elseif TeamUtils.isAwayPlayer(player) then
		return "Away"
	elseif TeamUtils.isOfficial(player) then
		return "Officials"
	elseif TeamUtils.isInLobby(player) then
		return "Lobby"
	end
	return "Unknown"
end

--- Verifica se dois jogadores são de times opostos
-- @param player1 Player - Primeiro jogador
-- @param player2 Player - Segundo jogador
-- @return boolean - true se forem oponentes
function TeamUtils.areOpponents(player1: Player, player2: Player): boolean
	if not player1 or not player2 then return false end
	
	local side1 = TeamUtils.getTeamSide(player1)
	local side2 = TeamUtils.getTeamSide(player2)
	
	-- Só são oponentes se ambos estiverem em jogo e em lados diferentes
	if side1 == "Home" and side2 == "Away" then return true end
	if side1 == "Away" and side2 == "Home" then return true end
	
	return false
end

--- Verifica se dois jogadores são do mesmo time/lado
-- @param player1 Player - Primeiro jogador
-- @param player2 Player - Segundo jogador
-- @return boolean - true se forem do mesmo lado
function TeamUtils.areSameTeam(player1: Player, player2: Player): boolean
	if not player1 or not player2 then return false end
	
	local side1 = TeamUtils.getTeamSide(player1)
	local side2 = TeamUtils.getTeamSide(player2)
	
	-- Só são do mesmo time se ambos estiverem em jogo
	if side1 == "Unknown" or side2 == "Unknown" then return false end
	if side1 == "Lobby" or side2 == "Lobby" then return false end
	if side1 == "Officials" or side2 == "Officials" then return false end
	
	return side1 == side2
end

--// ============================================================================
--// SETOR: FUNÇÕES PÚBLICAS - OBTER JOGADORES
--// ============================================================================

--- Retorna todos os jogadores do time Home (incluindo goleiro)
-- @return {Player} - Lista de jogadores Home
function TeamUtils.getHomePlayers(): {Player}
	local players = {}
	
	local homeTeam = Teams:FindFirstChild(HOME_TEAM_NAME)
	local homeGK = Teams:FindFirstChild(HOME_GK_NAME)
	
	if homeTeam then
		for _, player in homeTeam:GetPlayers() do
			table.insert(players, player)
		end
	end
	
	if homeGK then
		for _, player in homeGK:GetPlayers() do
			table.insert(players, player)
		end
	end
	
	return players
end

--- Retorna todos os jogadores do time Away (incluindo goleiro)
-- @return {Player} - Lista de jogadores Away
function TeamUtils.getAwayPlayers(): {Player}
	local players = {}
	
	local awayTeam = Teams:FindFirstChild(AWAY_TEAM_NAME)
	local awayGK = Teams:FindFirstChild(AWAY_GK_NAME)
	
	if awayTeam then
		for _, player in awayTeam:GetPlayers() do
			table.insert(players, player)
		end
	end
	
	if awayGK then
		for _, player in awayGK:GetPlayers() do
			table.insert(players, player)
		end
	end
	
	return players
end

--- Retorna todos os jogadores oponentes de um jogador específico
-- @param player Player - O jogador de referência
-- @return {Player} - Lista de jogadores oponentes
function TeamUtils.getOpponentPlayers(player: Player): {Player}
	if TeamUtils.isHomePlayer(player) then
		return TeamUtils.getAwayPlayers()
	elseif TeamUtils.isAwayPlayer(player) then
		return TeamUtils.getHomePlayers()
	end
	return {}
end

--- Retorna todos os jogadores do mesmo time/lado de um jogador
-- @param player Player - O jogador de referência
-- @return {Player} - Lista de jogadores do mesmo time
function TeamUtils.getTeammates(player: Player): {Player}
	if TeamUtils.isHomePlayer(player) then
		return TeamUtils.getHomePlayers()
	elseif TeamUtils.isAwayPlayer(player) then
		return TeamUtils.getAwayPlayers()
	end
	return {}
end

--// ============================================================================
--// SETOR: FUNÇÕES PÚBLICAS - UTILITÁRIOS
--// ============================================================================

--- Conta oponentes em um raio ao redor de uma posição (para marcação)
-- @param blacklistPlayer Player - Jogador a ignorar (normalmente o dono da bola)
-- @param center Vector3 - Centro da busca
-- @param radius number? - Raio de busca (padrão: 10)
-- @return number - Quantidade de oponentes no raio
function TeamUtils.countOpponentsInRadius(blacklistPlayer: Player, center: Vector3, radius: number?): number
	local r = radius or 10
	local radiusSquared = r * r
	local count = 0
	
	local opponents = TeamUtils.getOpponentPlayers(blacklistPlayer)
	
	for _, player in opponents do
		if player == blacklistPlayer then
			continue
		end
		
		local character = player.Character
		if character then
			local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if humanoidRootPart then
				local offset = humanoidRootPart.Position - center
				local distanceSquared = offset:Dot(offset)
				
				if distanceSquared <= radiusSquared then
					count += 1
				end
			end
		end
	end
	
	return count
end

return TeamUtils
