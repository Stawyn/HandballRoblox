local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local StatUtils = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Implementation"):WaitForChild("StatUtils"))
local Statistics = {}
Statistics.__index = Statistics

local StatsData = { [1] = {}, [2] = {} }
local MatchLog = {} -- Stores goal events: {Time = "00:00", Content = "..."}
local CurrentHalf = 1
local IsMatchActive = false
local LastPossessionTime = 0
local LastPossessionTeam = nil

-- Configuration
local WEBHOOK_URL = "https://discord.com/api/webhooks/1335013066607231088/646J139XfV-O5V9F-m0K2gYfI-D2wF_8O1u_x_x"
local DATA_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Data")
local TIMER = DATA_FOLDER:WaitForChild("Timer")

-- Ensure Network & RemoteEvent exist
local NetworkFolder = ReplicatedStorage:FindFirstChild("Network")
if not NetworkFolder then
	NetworkFolder = Instance.new("Folder")
	NetworkFolder.Name = "Network"
	NetworkFolder.Parent = ReplicatedStorage
end

local StatsEvent = NetworkFolder:FindFirstChild("StatsUpdate")
if not StatsEvent then
	StatsEvent = Instance.new("RemoteEvent")
	StatsEvent.Name = "StatsUpdate"
	StatsEvent.Parent = NetworkFolder
end

-- Dirty Flag for performance
local needsUpdate = false
local MatchName = "Partida_" .. os.date("%Y%m%d_%H%M")
local MatchDataStore = DataStoreService:GetDataStore("MatchStatistics_V1")

-- Internal flags to prevent duplicate webhook sends
local lastPeriodicMinute = nil
local halfEndSent = { [1] = false, [2] = false }

-- Keep last known player names so webhooks keep the original nick when players leave
local KnownNames = {}

-- Track player join/leave to capture latest name
Players.PlayerAdded:Connect(function(pl)
	KnownNames[pl.UserId] = pl.Name
end)
Players.PlayerRemoving:Connect(function(pl)
	KnownNames[pl.UserId] = pl.Name
end)

local function pad(text, length)
	text = tostring(text)
	if #text > length then return string.sub(text, 1, length) end
	return text .. string.rep(" ", length - #text)
end

local function addLog(text)
	local timerValue = (TIMER and TIMER.Value) or 0
	local m = math.floor(timerValue/60)
	local s = math.floor(timerValue%60)
	local timestamp = string.format("[%02d:%02d]", m, s)
	table.insert(MatchLog, {Time = timestamp, Content = text})
end

local function getServerCode()
	return tostring(game.JobId ~= "" and string.sub(game.JobId, 1, 8) or "Studio")
end

local function sendToDiscord(title, dataScope, isTotal, skipStats)
	-- Append server code to every title to identify the server
	local serverCode = getServerCode()
	title = title .. " - Server: " .. serverCode

	local payload = {
		["embeds"] = {{
			["title"] = title,
			["color"] = isTotal and 65280 or 52479,
			["fields"] = {},
			["footer"] = { ["text"] = "Tempo de Jogo: " .. math.floor((TIMER and TIMER.Value or 0)/60) .. "m | " .. MatchName },
			["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
		}}
	}

	if not skipStats and dataScope then
		local playerHeader = string.format("%s | MVP | G | A | CA | S | MIS | EF%% | STL | PAS | ERR\n%s", pad("JOGADOR", 4), string.rep("-", 60))
		local gkHeader = string.format("%s | DEF | GS | GKA | %%DEF\n%s", pad("GOLEIRO", 10), string.rep("-", 45))

		local playerBody = ""
		local gkBody = ""
		local hasGK = false

		local list = {}
		for uid, stats in pairs(dataScope) do
			local uidNum = tonumber(uid)
			local name = (stats and stats.Name and stats.Name ~= "") and stats.Name or KnownNames[uidNum] or "Player_"..uid
			local shortName = name
			if #shortName > 4 then shortName = string.sub(shortName, 1, 4) end

			local teamName = stats.LastTeamName or ""
			local color = "\27[1;32m" -- default green

			if teamName ~= "" then
				if string.find(string.lower(teamName), "away") then
					color = "\27[1;31m" -- red
				elseif string.find(string.lower(teamName), "home") then
					color = "\27[1;34m" -- blue
				end
			end

			local reset = "\27[0m"
			table.insert(list, {Name = shortName, FullName = name, Stats = stats, Color = color, Reset = reset})
		end

		for _, item in ipairs(list) do
			local s = item.Stats
			-- Pass character/player info for MVP if available
			local pObj = Players:GetPlayerByUserId(tonumber(_))
			StatUtils.CalculateDerivedStats(s, pObj)

			local ef = (s.EficPct or 0) .. "%"
			local dp = (s.DefPct or 0) .. "%"
			local passes = (s.PassesCompleted or 0) .. "/" .. (s.PassesAttempted or 0)
			local mvp = s.MVP or 0
			local misses = s.Misses or 0

			playerBody ..= string.format("%s%s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s%s\n",
				item.Color, pad(item.Name, 4), pad(mvp, 3), pad(s.Goals or 0, 1), pad(s.Assists or 0, 1), pad(s.FastBreakGoals or 0, 2), pad(s.SOG or 0, 1), pad(misses, 3), pad(ef, 3), pad(s.Steals or 0, 3), pad(passes, 5), pad(s.Turnovers or 0, 3), item.Reset
			)

			local isGK = ( (s.Saves or 0) > 0 or (s.SaveAttempts or 0) > 0 )
			if s.LastTeamName and string.sub(s.LastTeamName, 1, 1) == "-" then isGK = true end

			if isGK then
				hasGK = true
				gkBody ..= string.format("%s%s | %s | %s | %s | %s%s\n",
					item.Color, pad(item.Name, 10), pad(s.Saves or 0, 3), pad(s.GoalsConceded or 0, 2), pad(s.GKAssists or 0, 3), pad(dp, 4), item.Reset
				)
			end
		end

		table.insert(payload.embeds[1].fields, { ["name"] = "? JOGADORES", ["value"] = "```ansi\n" .. "\27[1;37m" .. playerHeader .. "\n" .. playerBody .. "```" })
		table.insert(payload.embeds[1].fields, { ["name"] = "?? GOLEIROS", ["value"] = hasGK and ("```ansi\n" .. "\27[1;37m" .. gkHeader .. "\n" .. gkBody .. "```") or "```\nSem dados de GK\n```" })

		-- Add Goal Log for relevant snapshots
		if #MatchLog > 0 then
			local logText = ""
			local startIdx = math.max(1, #MatchLog - 5) -- Show last 5 goals
			for i = startIdx, #MatchLog do
				logText ..= MatchLog[i].Time .. " " .. MatchLog[i].Content .. "\n"
			end
			table.insert(payload.embeds[1].fields, { ["name"] = "?? LOG DE GOLS", ["value"] = "```\n" .. logText .. "```" })
		end
	end

	pcall(function()
		HttpService:PostAsync(WEBHOOK_URL, HttpService:JSONEncode(payload))
	end)
end

function Statistics.GetPlayerStats(player, half)
	if not player then return nil end
	local userId = tostring(player.UserId)
	if not StatsData[half] then StatsData[half] = {} end
	if not StatsData[half][userId] then
		StatsData[half][userId] = StatUtils.InitPlayerStats()
	end
	local s = StatsData[half][userId]
	s.Name = player.Name
	s.LastTeamName = (player.Team and player.Team.Name) or s.LastTeamName
	KnownNames[player.UserId] = player.Name
	return s
end

function Statistics.SetMatchName(name)
	MatchName = name or MatchName
end

function Statistics.SaveMatch()
	local totalStats = Statistics.GetCombinedStats()
	local data = {
		Name = MatchName,
		Date = os.date("%Y-%m-%d %H:%M:%S"),
		Log = MatchLog,
		Stats = totalStats
	}
	local key = "Match_" .. HttpService:GenerateGUID(false)
	local success, err = pcall(function()
		MatchDataStore:SetAsync(key, data)
	end)
	if success then
		print("Statistics: Match saved to DataStore as", key)
		return true
	else
		warn("Statistics: Failed to save match:", err)
		return false
	end
end

function Statistics.GetCombinedStats()
	local combined = {}
	for h=1,2 do 
		for uid, s in pairs(StatsData[h]) do 
			if not combined[uid] then combined[uid] = StatUtils.InitPlayerStats() end
			combined[uid] = StatUtils.MergeStats(combined[uid], s)
		end 
	end
	-- Recalculate MVP/Derived for everyone
	for uid, s in pairs(combined) do
		local p = Players:GetPlayerByUserId(tonumber(uid))
		StatUtils.CalculateDerivedStats(s, p)
	end
	return combined
end

function Statistics.StartMatch()
	if IsMatchActive and CurrentHalf == 1 then return end
	print("Statistics: Starting Match")
	Statistics.Reset()
	IsMatchActive = true
	CurrentHalf = 1
	lastPeriodicMinute = nil
	halfEndSent[1] = false
	halfEndSent[2] = false
	MatchLog = {}
	if DATA_FOLDER and DATA_FOLDER:FindFirstChild("MatchPaused") then DATA_FOLDER.MatchPaused.Value = false end
	pcall(function() sendToDiscord("?? PARTIDA INICIADA - 1º TEMPO", nil, false, true) end)
end

function Statistics.StartHalf(half)
	CurrentHalf = half
	IsMatchActive = true
	if DATA_FOLDER and DATA_FOLDER:FindFirstChild("MatchPaused") then DATA_FOLDER.MatchPaused.Value = false end
	lastPeriodicMinute = nil
	halfEndSent[half] = false
	if not StatsData[half] then StatsData[half] = {} end
	local halfLabel = (half == 1) and "1º TEMPO" or "2º TEMPO"
	pcall(function() sendToDiscord("?? INÍCIO DO " .. halfLabel, nil, false, true) end)
end

function Statistics.PauseMatch()
	if not IsMatchActive then return end
	IsMatchActive = false
	if DATA_FOLDER and DATA_FOLDER:FindFirstChild("MatchPaused") then DATA_FOLDER.MatchPaused.Value = true end
	Statistics.BroadcastUpdate(true) -- Force update
	pcall(function() sendToDiscord("?? PARTIDA PAUSADA", nil, false, true) end)
end

function Statistics.ResumeMatch()
	if IsMatchActive then return end
	IsMatchActive = true
	if DATA_FOLDER and DATA_FOLDER:FindFirstChild("MatchPaused") then DATA_FOLDER.MatchPaused.Value = false end
	Statistics.BroadcastUpdate(true)
	pcall(function() sendToDiscord("?? PARTIDA RETOMADA", nil, false, true) end)
end

function Statistics.RecordTeamGoal(isHome, scorer, assistant)
	local title = (isHome and "? GOL - HOME") or "? GOL - AWAY"
	local logText = (isHome and "GOL HOME") or "GOL AWAY"
	if scorer then
		logText ..= " - " .. scorer.Name
		if assistant then logText ..= " (Assist: " .. assistant.Name .. ")" end
	end
	addLog(logText)
	Statistics.BroadcastUpdate(true)
	pcall(function() sendToDiscord(title, StatsData[CurrentHalf], false) end)
end

function Statistics.NotifyTeamNameChange(name, isHome)
	local side = isHome and "Home" or "Away"
	pcall(function() sendToDiscord("?? NOME DE TIME ALTERADO - " .. side .. ": " .. tostring(name), nil, false, true) end)
end

function Statistics.FinishMatch()
	if not IsMatchActive and halfEndSent[2] then return end -- Already finished
	IsMatchActive = false
	halfEndSent[2] = true

	-- Award Clean Sheets to GKs who played and conceded 0 goals
	for half = 1, 2 do
		if StatsData[half] then
			for id, stats in pairs(StatsData[half]) do
				-- If they were marked as GK (SaveAttempts > 0) and zero goals conceded
				if (stats.SaveAttempts or 0) > 0 and (stats.GoalsConceded or 0) == 0 then
					stats.CleanSheets = (stats.CleanSheets or 0) + 1
				end
			end
		end
	end

	local combined = Statistics.GetCombinedStats()
	sendToDiscord("?? ESTATÍSTICAS FINAIS (TOTAL)", combined, true)
	Statistics.SaveMatch()
end

function Statistics.Reset()
	StatsData = { [1] = {}, [2] = {} }
	MatchLog = {}
	CurrentHalf = 1
	IsMatchActive = false
	halfEndSent = { [1] = false, [2] = false }
	lastPeriodicMinute = nil
	if StatsEvent then StatsEvent:FireAllClients("Reset") end
end

function Statistics.RecordEvent(player, eventType, value)
	if not IsMatchActive or not player then return end
	local stats = Statistics.GetPlayerStats(player, CurrentHalf)
	if not stats then return end

	needsUpdate = true
	if eventType == "Goal" then
		stats.Goals += 1
	elseif eventType == "Assist" then
		stats.Assists += 1
	elseif eventType == "SOG" then
		stats.SOG += 1
		stats.Shots += 1
	elseif eventType == "SavedShot" then
		stats.SavedShots += 1
	elseif eventType == "ShotMiss" then
		stats.Shots += 1
	elseif eventType == "FastBreak" then
		stats.FastBreakGoals += 1
		stats.Goals += 1
		stats.SOG += 1
		stats.Shots += 1
	elseif eventType == "Steal" then
		stats.Steals += 1
	elseif eventType == "Save" then
		stats.Saves += 1
		stats.SaveAttempts += 1
	elseif eventType == "GoalConceded" then
		stats.GoalsConceded += 1
		stats.SaveAttempts += 1
	elseif eventType == "PenaltySave" then
		stats.PenaltiesSaved += 1
		stats.Saves += 1
		stats.SaveAttempts += 1
	elseif eventType == "GKAssist" then
		stats.GKAssists += 1
	elseif eventType == "PassComplete" then
		stats.PassesCompleted += 1
	elseif eventType == "PassFailed" then
		stats.PassesFailed += 1
	elseif eventType == "PassAttempt" then
		stats.PassesAttempted += 1
	elseif eventType == "Turnover" then
		stats.Turnovers += 1
	elseif eventType == "PossessionStart" then
		stats.PossessionCount += 1
	elseif eventType == "Possession" then
		stats.PossessionTime += (value or 0)
		needsUpdate = false -- don't trigger broadcast just for incremental possession decimals
	end
end

function Statistics.BroadcastUpdate(force)
	if not StatsEvent then return end
	if force or needsUpdate then
		StatsEvent:FireAllClients("Update", StatsData)
		needsUpdate = false
	end
end

function Statistics.SendHalfEnd(half)
	if not half or not StatsData[half] then return end
	local halfLabel = (half == 1) and "1º TEMPO" or "2º TEMPO"
	pcall(function() sendToDiscord("? FIM DO " .. halfLabel, StatsData[half], false) end)
end

task.spawn(function()
	while true do
		task.wait(0.5) -- Throttled broadcast loop (Faster updates requested)
		if IsMatchActive then
			Statistics.BroadcastUpdate()
		end

		if IsMatchActive and TIMER then
			local timerValue = TIMER.Value or 0
			local minutes = math.floor(timerValue/60)
			local halfLabel = (CurrentHalf == 1) and "1º TEMPO" or "2º TEMPO"

			if timerValue > 0 and timerValue % 120 == 0 then
				if lastPeriodicMinute ~= minutes then
					lastPeriodicMinute = minutes
					sendToDiscord("?? ATUALIZAção - " .. halfLabel .. " - " .. tostring(minutes) .. " min", StatsData[CurrentHalf], false)
				end
			end

			local HALF_DURATION = 600
			local added = (DATA_FOLDER and DATA_FOLDER:FindFirstChild("AddedTime") and DATA_FOLDER.AddedTime.Value) or 0
			local halfEndMarker = HALF_DURATION + added

			if timerValue >= halfEndMarker and not halfEndSent[CurrentHalf] then
				if CurrentHalf == 1 then
					halfEndSent[1] = true
					Statistics.SendHalfEnd(1)
				else
					Statistics.FinishMatch()
				end
			end
		end
	end
end)

return Statistics

