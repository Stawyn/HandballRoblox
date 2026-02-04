--[[
	================================================================================
	MÓDULO: TeamUtils (Utilitários de Times)
	================================================================================
	
	Descrição:
		Funções centralizadas para verificação de times de jogadores.
		Evita duplicação de padrões como "teamName:find('Home')" em vários arquivos.
	
	Funções:
		- isHomePlayer: Verifica se jogador é do time Home
		- isAwayPlayer: Verifica se jogador é do time Away
		- isGoalkeeper: Verifica se jogador é goleiro
		- isSubstitute: Verifica se jogador é reserva
		- isOfficial: Verifica se jogador é árbitro
		- getPlayerTeamSide: Retorna "Home", "Away" ou nil
	
	Autor: Sistema ABH
	================================================================================
]]

--// ============================================================================
--// SETOR: Definição do Módulo
--// ============================================================================

local TeamUtils = {}

--// ============================================================================
--// SETOR: Constantes de Nomes de Times
--// ============================================================================

local TEAM_PATTERNS = {
	HOME = "Home",
	AWAY = "Away",
	GOALKEEPER = "Goalkeeper",
	SUBSTITUTES = "Substitutes",
	OFFICIALS = "Officials",
	LOBBY = "Lobby"
}

--// ============================================================================
--// SETOR: Funções de Verificação de Time
--// ============================================================================

--- Verifica se o jogador é do time Home (titular)
-- @param player Player - O jogador a verificar
-- @return boolean - true se é jogador titular do Home
function TeamUtils.isHomePlayer(player: Player): boolean
	if not player.Team then
		return false
	end

	local teamName = player.Team.Name
	return teamName:find(TEAM_PATTERNS.HOME) ~= nil 
		and teamName:find(TEAM_PATTERNS.SUBSTITUTES) == nil
end

--- Verifica se o jogador é do time Away (titular)
-- @param player Player - O jogador a verificar
-- @return boolean - true se é jogador titular do Away
function TeamUtils.isAwayPlayer(player: Player): boolean
	if not player.Team then
		return false
	end

	local teamName = player.Team.Name
	return teamName:find(TEAM_PATTERNS.AWAY) ~= nil 
		and teamName:find(TEAM_PATTERNS.SUBSTITUTES) == nil
end

--- Verifica se o jogador é goleiro
-- @param player Player - O jogador a verificar
-- @return boolean - true se é goleiro
function TeamUtils.isGoalkeeper(player: Player): boolean
	if not player.Team then
		return false
	end

	return player.Team.Name:find(TEAM_PATTERNS.GOALKEEPER) ~= nil
end

--- Verifica se o jogador é reserva (Substitutes)
-- @param player Player - O jogador a verificar
-- @return boolean - true se é reserva
function TeamUtils.isSubstitute(player: Player): boolean
	if not player.Team then
		return false
	end

	return player.Team.Name:find(TEAM_PATTERNS.SUBSTITUTES) ~= nil
end

--- Verifica se o jogador é árbitro (Officials)
-- @param player Player - O jogador a verificar
-- @return boolean - true se é árbitro
function TeamUtils.isOfficial(player: Player): boolean
	if not player.Team then
		return false
	end

	return player.Team.Name == TEAM_PATTERNS.OFFICIALS
end

--- Verifica se o jogador está no Lobby
-- @param player Player - O jogador a verificar
-- @return boolean - true se está no lobby
function TeamUtils.isInLobby(player: Player): boolean
	if not player.Team then
		return false
	end

	return player.Team.Name == TEAM_PATTERNS.LOBBY
end

--- Retorna o lado do time do jogador ("Home", "Away", ou nil)
-- @param player Player - O jogador a verificar
-- @return string? - "Home", "Away" ou nil se não está em nenhum time
function TeamUtils.getPlayerTeamSide(player: Player): string?
	if not player.Team then
		return nil
	end

	local teamName = player.Team.Name

	-- Ignora reservas para fins de posse
	if teamName:find(TEAM_PATTERNS.SUBSTITUTES) then
		return nil
	end

	if teamName:find(TEAM_PATTERNS.HOME) then
		return "Home"
	elseif teamName:find(TEAM_PATTERNS.AWAY) then
		return "Away"
	end

	return nil
end

--- Verifica se o jogador pode interagir com a bola (não é lobby/officials/substitutes)
-- @param player Player - O jogador a verificar
-- @return boolean - true se pode interagir
function TeamUtils.canInteractWithBall(player: Player): boolean
	if not player.Team then
		return false
	end

	local teamName = player.Team.Name

	-- não pode jogar se está no lobby, é árbitro ou reserva
	if teamName == TEAM_PATTERNS.LOBBY then
		return false
	end
	if teamName == TEAM_PATTERNS.OFFICIALS then
		return false
	end
	if teamName:find(TEAM_PATTERNS.SUBSTITUTES) then
		return false
	end

	return true
end

--- Verifica se dois jogadores são do mesmo lado (Home vs Away)
-- @param player1 Player - Primeiro jogador
-- @param player2 Player - Segundo jogador
-- @return boolean - true se são do mesmo lado
function TeamUtils.areSameTeamSide(player1: Player, player2: Player): boolean
	local side1 = TeamUtils.getPlayerTeamSide(player1)
	local side2 = TeamUtils.getPlayerTeamSide(player2)

	if side1 == nil or side2 == nil then
		return false
	end

	return side1 == side2
end

--- Verifica se dois jogadores são adversários
-- @param player1 Player - Primeiro jogador
-- @param player2 Player - Segundo jogador
-- @return boolean - true se são adversários
function TeamUtils.areOpponents(player1: Player, player2: Player): boolean
	local side1 = TeamUtils.getPlayerTeamSide(player1)
	local side2 = TeamUtils.getPlayerTeamSide(player2)

	if side1 == nil or side2 == nil then
		return false
	end

	return side1 ~= side2
end

--// ============================================================================
--// SETOR: Retorno do Módulo
--// ============================================================================

return TeamUtils

