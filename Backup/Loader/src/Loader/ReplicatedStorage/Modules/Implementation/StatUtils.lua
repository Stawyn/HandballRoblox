local StatUtils = {}

StatUtils.WEIGHTS = {
	GOAL = 4,
	ASSIST = 2,
	STEAL = 2,
	POSSESSION_5S = 1,
	PASS_COMPLETE = 1,
	SOG = 1,
	FAST_BREAK = 1,
	TURNOVER = -1,
	MISS = -1,
	-- GK Weights
	GK_SAVE = 2,
	GK_GOAL_CONCEDED = -2,
	GK_ASSIST = 2,
	GK_GOAL = 4,
	GK_CLEAN_SHEET = 5
}

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
		-- Metadata
		Name = "",
		LastTeamName = ""
	}
end

function StatUtils.IsGK(pObj)
	if not pObj or not pObj.Team or not pObj.Team.Name then return false end
	return string.sub(pObj.Team.Name, 1, 1) == "-" or string.find(pObj.Team.Name, "Goalkeeper") ~= nil
end

function StatUtils.CalculateMVP(s, pObj)
	if not s then return 0 end

	-- Identify GK
	local isGK = StatUtils.IsGK(pObj)
	if (s.Saves or 0) > 0 then isGK = true end

	local penaltyGoals = s.PenaltyGoals or 0
	local goals = math.max(0, (s.Goals or 0) - penaltyGoals)

	if isGK then
		local saves = s.Saves or 0
		local gc = s.GoalsConceded or 0
		local gkAssists = s.GKAssists or 0
		local gkGoals = goals

		local score = (saves * StatUtils.WEIGHTS.GK_SAVE) 
			+ (gc * StatUtils.WEIGHTS.GK_GOAL_CONCEDED) 
			+ (gkAssists * StatUtils.WEIGHTS.GK_ASSIST) 
			+ (gkGoals * StatUtils.WEIGHTS.GK_GOAL)

		local csCount = s.CleanSheets or 0
		if csCount == 0 and gc == 0 and (saves > 0 or s.SaveAttempts > 0) then
			csCount = 1
		end
		score += (csCount * StatUtils.WEIGHTS.GK_CLEAN_SHEET)

		return math.floor(math.max(0, score))
	else
		local assists = s.Assists or 0
		local steals = s.Steals or 0
		local passesCompleted = s.PassesCompleted or 0
		local sog = s.SOG or 0
		local fastBreakGoals = s.FastBreakGoals or 0
		local turnovers = s.Turnovers or 0
		local misses = math.max(0, (s.Shots or 0) - sog)
		local possessionPoints = math.floor((s.PossessionTime or 0) / 5)

		local score = (goals * StatUtils.WEIGHTS.GOAL) 
			+ (assists * StatUtils.WEIGHTS.ASSIST) 
			+ (steals * StatUtils.WEIGHTS.STEAL) 
			+ (possessionPoints * StatUtils.WEIGHTS.POSSESSION_5S) 
			+ (passesCompleted * StatUtils.WEIGHTS.PASS_COMPLETE) 
			+ (sog * StatUtils.WEIGHTS.SOG) 
			+ (fastBreakGoals * StatUtils.WEIGHTS.FAST_BREAK)
			+ (turnovers * StatUtils.WEIGHTS.TURNOVER) 
			+ (misses * StatUtils.WEIGHTS.MISS)

		return math.floor(math.max(0, score))
	end
end

function StatUtils.CalculateDerivedStats(stats, pObj)
	if not stats then return end
	local goals = stats.Goals or 0
	local savedShots = stats.SavedShots or 0
	local shotAttempts = stats.Shots or 0

	-- SOG: Goals + SavedShots if not provided
	local sog = stats.SOG or (goals + savedShots)
	stats.SOG = sog

	-- Misses
	local misses = math.max(0, shotAttempts - sog)
	stats.Misses = misses

	-- Efficiency %
	local totalAttempts = sog + misses
	stats.EficPct = totalAttempts > 0 and math.floor((goals / totalAttempts) * 100) or 0

	-- Defense %
	local saves = stats.Saves or 0
	local gc = stats.GoalsConceded or 0
	local totalFaced = saves + gc
	stats.DefPct = totalFaced > 0 and math.floor((saves / totalFaced) * 100) or 0

	-- MVP
	stats.MVP = StatUtils.CalculateMVP(stats, pObj)
end

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
