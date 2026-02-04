--[[
    ================================================================================
    MÓDULO: StatUtils
    ================================================================================
    Descrição: Utilitários de estatísticas - cálculo de MVP, inicialização
               e merge de stats de jogadores.
    
    Funcionalidades:
        - InitPlayerStats: Template de estatísticas
        - CalculateMVP: Pontuação MVP (pesos diferentes para GK)
        - CalculateDerivedStats: Estatísticas derivadas (SOG, Eficiência)
        - MergeStats: Combina estatísticas de dois objetos
    
    Pesos MVP:
        - GOAL: 4, ASSIST: 2, STEAL: 2
        - GK_SAVE: 2, GK_CLEAN_SHEET: 5
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: MÓDULO
--// ============================================================================

local StatUtils = {}

--// ============================================================================
--// SETOR: CONSTANTES - PESOS MVP
--// ============================================================================

StatUtils.RATING_WEIGHTS = {
	BASE_RATING = 6.0,
	-- Field Players
	GOAL = 1.0,
	ASSIST = 0.8,
	STEAL = 0.5,
	PASS_COMPLETE = 0.02,
	SOG = 0.1,
	TURNOVER = -0.2,
	MISS = -0.1,
	-- Goalkeepers
	GK_SAVE = 0.8,
	GK_GOAL_CONCEDED = -0.5,
	GK_CLEAN_SHEET = 1.0,
	GK_ASSIST = 1.0
}

--// ============================================================================
--// SETOR: FUNÇÕES DE INICIALIZAÇÃO
--// ============================================================================

--- Cria template de estatísticas do jogador
function StatUtils.InitPlayerStats()
	return {
		Goals = 0,
		Assists = 0,
		SOG = 0,
		Shots = 0,
		SavedShots = 0,
		PossessionCount = 0,
		FastBreakGoals = 0,
		Steals = 0,
		Saves = 0,
		SaveAttempts = 0,
		PenaltiesSaved = 0,
		GKAssists = 0,
		GoalsConceded = 0,
		PassesAttempted = 0,
		PassesCompleted = 0,
		PassesFailed = 0,
		PossessionTime = 0,
		Turnovers = 0,
		CleanSheets = 0,
		
		Rating = 6.0, -- Default start
		
		-- Metadata
		Name = "",
		LastTeamName = ""
	}
end

--// ============================================================================
--// SETOR: FUNÇÕES AUXILIARES
--// ============================================================================

--- Verifica se jogador é goleiro
function StatUtils.IsGK(pObj): boolean
	if not pObj or not pObj.Team or not pObj.Team.Name then return false end
	return string.sub(pObj.Team.Name, 1, 1) == "-" or string.find(pObj.Team.Name, "Goalkeeper") ~= nil
end

--// ============================================================================
--// SETOR: CÁLCULO DE RATING (FIFA STYLE)
--// ============================================================================

--- Calcula nota (Rating) do jogador (0.0 - 10.0)
-- @param s table - Estatísticas do jogador
-- @param pObj Player - Objeto do jogador
-- @return number - Rating
function StatUtils.CalculateRating(s, pObj): number
	if not s then return 6.0 end

	-- Identifica GK
	local isGK = StatUtils.IsGK(pObj)
	if (s.Saves or 0) > 0 then isGK = true end

	local rating = StatUtils.RATING_WEIGHTS.BASE_RATING
	local w = StatUtils.RATING_WEIGHTS

	local penaltyGoals = s.PenaltyGoals or 0
	local goals = math.max(0, (s.Goals or 0) - penaltyGoals)

	if isGK then
		-- Goleiro
		rating += (s.Saves or 0) * w.GK_SAVE
		rating += (s.GoalsConceded or 0) * w.GK_GOAL_CONCEDED
		rating += (s.GKAssists or 0) * w.GK_ASSIST
		rating += (s.Goals or 0) * w.GOAL -- Goleiro fazendo gol ganha ponto de linha tbm
		rating += (s.PassesCompleted or 0) * w.PASS_COMPLETE
		
		if (s.CleanSheets or 0) > 0 then
			rating += w.GK_CLEAN_SHEET
		end
	else
		-- Linha
		rating += goals * w.GOAL
		rating += (s.Assists or 0) * w.ASSIST
		rating += (s.Steals or 0) * w.STEAL
		rating += (s.PassesCompleted or 0) * w.PASS_COMPLETE
		rating += (s.SOG or 0) * w.SOG
		rating += (s.Turnovers or 0) * w.TURNOVER
		
		local misses = math.max(0, (s.Shots or 0) - (s.SOG or 0))
		rating += misses * w.MISS
	end

	-- Clamp entre 1.0 e 10.0 (FIFA raramente da 0, mas vamos por 1.0 de min)
	return math.clamp(rating, 1.0, 10.0)
end

--// ============================================================================
--// SETOR: ESTATÍSTICAS DERIVADAS
--// ============================================================================

--- Calcula estatísticas derivadas (SOG, Eficiência, Defesa %)
function StatUtils.CalculateDerivedStats(stats, pObj)
	if not stats then return end
	
	local goals = stats.Goals or 0
	local savedShots = stats.SavedShots or 0
	local shotAttempts = stats.Shots or 0

	-- SOG
	local sog = stats.SOG or (goals + savedShots)
	stats.SOG = sog

	-- Misses
	local misses = math.max(0, shotAttempts - sog)
	stats.Misses = misses

	-- Eficiência %
	local totalAttempts = sog + misses
	stats.EficPct = totalAttempts > 0 and math.floor((goals / totalAttempts) * 100) or 0

	-- Defesa %
	local saves = stats.Saves or 0
	local gc = stats.GoalsConceded or 0
	local totalFaced = saves + gc
	stats.DefPct = totalFaced > 0 and math.floor((saves / totalFaced) * 100) or 0

	-- Rating
	stats.Rating = StatUtils.CalculateRating(stats, pObj)
end

--// ============================================================================
--// SETOR: MERGE DE ESTATÍSTICAS
--// ============================================================================

--- Combina estatísticas de dois objetos
function StatUtils.MergeStats(s1, s2)
	local combined = StatUtils.InitPlayerStats()
	
	for k, v in pairs(combined) do
		if type(v) == "number" then
			combined[k] = (s1[k] or 0) + (s2[k] or 0)
		end
	end
	
	combined.Name = s1.Name ~= "" and s1.Name or s2.Name
	combined.LastTeamName = s2.LastTeamName ~= "" and s2.LastTeamName or s1.LastTeamName
	
	return combined
end

return StatUtils
