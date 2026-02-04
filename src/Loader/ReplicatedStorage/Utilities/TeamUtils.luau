--[[
	================================================================================
	MÃ“DULO: TeamUtils (UtilitÃ¡rios de Times)
	================================================================================
	
	DescriÃ§Ã£o:
		FunÃ§Ãµes centralizadas para verificaÃ§Ã£o de times de jogadores.
		Evita duplicaÃ§Ã£o de padrÃµes como "teamName:find('Home')" em vÃ¡rios arquivos.
	
	FunÃ§Ãµes:
		- isHomePlayer: Verifica se jogador Ã© do time Home
		- isAwayPlayer: Verifica se jogador Ã© do time Away
		- isGoalkeeper: Verifica se jogador Ã© goleiro
		- isSubstitute: Verifica se jogador Ã© reserva
		- isOfficial: Verifica se jogador Ã© Ã¡rbitro
		- getPlayerTeamSide: Retorna "Home", "Away" ou nil
	
	Autor: Sistema ABH
	================================================================================
]]

--// ============================================================================
--// SETOR: DefiniÃ§Ã£o do MÃ³dulo
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
--// SETOR: FunÃ§Ãµes de VerificaÃ§Ã£o de Time
--// ============================================================================

--- Verifica se o jogador Ã© do time Home (titular)
-- @param player Player - O jogador a verificar
-- @return boolean - true se Ã© jogador titular do Home
function TeamUtils.isHomePlayer(player: Player): boolean
	if not player.Team then
		return false
	end

	local teamName = player.Team.Name
	return teamName:find(TEAM_PATTERNS.HOME) ~= nil 
		and teamName:find(TEAM_PATTERNS.SUBSTITUTES) == nil
end

--- Verifica se o jogador Ã© do time Away (titular)
-- @param player Player - O jogador a verificar
-- @return boolean - true se Ã© jogador titular do Away
function TeamUtils.isAwayPlayer(player: Player): boolean
	if not player.Team then
		return false
	end

	local teamName = player.Team.Name
	return teamName:find(TEAM_PATTERNS.AWAY) ~= nil 
		and teamName:find(TEAM_PATTERNS.SUBSTITUTES) == nil
end

--- Verifica se o jogador Ã© goleiro
-- @param player Player - O jogador a verificar
-- @return boolean - true se Ã© goleiro
function TeamUtils.isGoalkeeper(player: Player): boolean
	if not player.Team then
		return false
	end

	return player.Team.Name:find(TEAM_PATTERNS.GOALKEEPER) ~= nil
end

--- Verifica se o jogador Ã© reserva (Substitutes)
-- @param player Player - O jogador a verificar
-- @return boolean - true se Ã© reserva
function TeamUtils.isSubstitute(player: Player): boolean
	if not player.Team then
		return false
	end

	return player.Team.Name:find(TEAM_PATTERNS.SUBSTITUTES) ~= nil
end

--- Verifica se o jogador Ã© Ã¡rbitro (Officials)
-- @param player Player - O jogador a verificar
-- @return boolean - true se Ã© Ã¡rbitro
function TeamUtils.isOfficial(player: Player): boolean
	if not player.Team then
		return false
	end

	return player.Team.Name == TEAM_PATTERNS.OFFICIALS
end

--- Verifica se o jogador estÃ¡ no Lobby
-- @param player Player - O jogador a verificar
-- @return boolean - true se estÃ¡ no lobby
function TeamUtils.isInLobby(player: Player): boolean
	if not player.Team then
		return false
	end

	return player.Team.Name == TEAM_PATTERNS.LOBBY
end

--- Retorna o lado do time do jogador ("Home", "Away", ou nil)
-- @param player Player - O jogador a verificar
-- @return string? - "Home", "Away" ou nil se nÃ£o estÃ¡ em nenhum time
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

--- Verifica se o jogador pode interagir com a bola (nÃ£o Ã© lobby/officials/substitutes)
-- @param player Player - O jogador a verificar
-- @return boolean - true se pode interagir
function TeamUtils.canInteractWithBall(player: Player): boolean
	if not player.Team then
		return false
	end

	local teamName = player.Team.Name

	-- NÃ£o pode jogar se estÃ¡ no lobby, Ã© Ã¡rbitro ou reserva
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

--- Verifica se dois jogadores sÃ£o do mesmo lado (Home vs Away)
-- @param player1 Player - Primeiro jogador
-- @param player2 Player - Segundo jogador
-- @return boolean - true se sÃ£o do mesmo lado
function TeamUtils.areSameTeamSide(player1: Player, player2: Player): boolean
	local side1 = TeamUtils.getPlayerTeamSide(player1)
	local side2 = TeamUtils.getPlayerTeamSide(player2)

	if side1 == nil or side2 == nil then
		return false
	end

	return side1 == side2
end

--- Verifica se dois jogadores sÃ£o adversÃ¡rios
-- @param player1 Player - Primeiro jogador
-- @param player2 Player - Segundo jogador
-- @return boolean - true se sÃ£o adversÃ¡rios
function TeamUtils.areOpponents(player1: Player, player2: Player): boolean
	local side1 = TeamUtils.getPlayerTeamSide(player1)
	local side2 = TeamUtils.getPlayerTeamSide(player2)

	if side1 == nil or side2 == nil then
		return false
	end

	return side1 ~= side2
end

--// ============================================================================
--// SETOR: Retorno do MÃ³dulo
--// ============================================================================

return TeamUtils

