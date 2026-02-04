--[[
    ================================================================================
    MÓDULO: GameStatistics
    ================================================================================
    Descrição: Sistema de estatísticas do jogo ABH que rastreia eventos de partida,
               envia atualizações para Discord via webhook e persiste dados.
    
    Funcionalidades:
        - Registro de eventos (gols, assistências, defesas, etc.)
        - Cálculo de estatísticas derivadas (MVP, eficiência, etc.)
        - Integração com Discord via webhooks
        - Persistência em DataStore
        - Broadcast em tempo real para clientes
    
    Tipos de Eventos:
        - Goal, Assist, SOG, ShotMiss, FastBreak
        - Save, GoalConceded, PenaltySave, GKAssist
        - PassComplete, PassFailed, Turnover, Steal
        - PossessionStart, Possession
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: SERVIÇOS E DEPENDÊNCIAS
--// ============================================================================

-- Serviços Roblox
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

-- Módulos
local StatUtils = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Implementation"):WaitForChild("StatUtils"))
local HtmlTemplates = require(script.Parent.HtmlTemplates)

--// ============================================================================
--// SETOR: MÓDULO E ESTADO
--// ============================================================================

local Statistics = {}
Statistics.__index = Statistics

-- Dados de estatísticas por tempo de jogo
local StatsData = { [1] = {}, [2] = {} }
local MatchLog = {} -- Armazena eventos de gol: {Time = "00:00", Content = "..."}
local CurrentHalf = 1
local IsMatchActive = false
local LastPossessionTime = 0
local LastPossessionTeam = nil

--// ============================================================================
--// SETOR: CONFIGURAÇÃO
--// ============================================================================

-- NOTA: Substitua pela URL do seu webhook em produção
local WEBHOOK_URL = "https://discord.com/api/webhooks/1467145002999349501/wkyNr-FyiHJESxcAdrl-NVRyOfwjMm67_dN_MFEml2hKSKmS8scz_1Dq2RQdTFzeZBEL"

-- Referências de dados
local DATA_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Data")
local TIMER = DATA_FOLDER:WaitForChild("Timer")

-- Garante que Network e RemoteEvent existam
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

--// ============================================================================
--// SETOR: FLAGS E CACHE
--// ============================================================================

-- Flag de atualização para performance
local needsUpdate = false
local MatchName = "Partida_" .. os.date("%Y%m%d_%H%M")
local MatchDataStore = DataStoreService:GetDataStore("MatchStatistics_V1")

-- Flags internas para evitar envios duplicados de webhook
local lastPeriodicMinute = nil
local halfEndSent = { [1] = false, [2] = false }

-- Mantém nomes conhecidos de jogadores para webhooks após saírem
local KnownNames = {}

--// ============================================================================
--// SETOR: LISTENERS DE JOGADORES
--// ============================================================================

-- Rastreia join/leave para capturar último nome
Players.PlayerAdded:Connect(function(pl)
	KnownNames[pl.UserId] = pl.Name
end)
Players.PlayerRemoving:Connect(function(pl)
	KnownNames[pl.UserId] = pl.Name
end)

--// ============================================================================
--// SETOR: FUNÇÕES AUXILIARES
--// ============================================================================

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



local function GenerateMatchStatsHTML(totalStats)
	local template = HtmlTemplates.GetTemplate()
	
	-- Preencher Header
	local homeScore = (DATA_FOLDER and DATA_FOLDER:FindFirstChild("HomeScore") and DATA_FOLDER.HomeScore.Value) or 0
	local awayScore = (DATA_FOLDER and DATA_FOLDER:FindFirstChild("AwayScore") and DATA_FOLDER.AwayScore.Value) or 0
	local homeName = (DATA_FOLDER and DATA_FOLDER:FindFirstChild("HomeName") and DATA_FOLDER.HomeName.Value) or "HOME"
	local awayName = (DATA_FOLDER and DATA_FOLDER:FindFirstChild("AwayName") and DATA_FOLDER.AwayName.Value) or "AWAY"
	local timerVal = (TIMER and TIMER.Value) or 0
	local m = math.floor(timerVal/60)
	local s = math.floor(timerVal%60)
	local timeStr = string.format("%02d:%02d", m, s)
	
	template = string.gsub(template, "{{HOME_NAME}}", homeName)
	template = string.gsub(template, "{{AWAY_NAME}}", awayName)
	template = string.gsub(template, "{{HOME_SCORE}}", tostring(homeScore))
	template = string.gsub(template, "{{AWAY_SCORE}}", tostring(awayScore))
	template = string.gsub(template, "{{MATCH_TIME}}", timeStr)
	template = string.gsub(template, "{{MATCH_ID}}", MatchName)
	template = string.gsub(template, "{{SERVER_ID}}", getServerCode())
	
	-- Calcular MVP (Maior Rating)
	local highestRating = -1
	local mvpUid = nil
	for uid, stats in pairs(totalStats) do
		if not stats.Rating then StatUtils.CalculateDerivedStats(stats, nil) end
		if (stats.Rating or 0) > highestRating then
			highestRating = stats.Rating
			mvpUid = uid
		end
	end

	-- Gerar linhas de jogadores
	local homeRows = ""
	local awayRows = ""
	
	for uid, stats in pairs(totalStats) do
		local isMvp = (uid == mvpUid)
		local row = HtmlTemplates.GenerateRow(stats, isMvp)
		
		local teamName = stats.LastTeamName or ""
		if string.find(string.lower(teamName), "home") then
			homeRows ..= row
		elseif string.find(string.lower(teamName), "away") then
			awayRows ..= row
		end
	end
	
	template = string.gsub(template, "{{HOME_ROWS}}", function() return homeRows end)
	template = string.gsub(template, "{{AWAY_ROWS}}", function() return awayRows end)
	
	return template
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
	
	local function doSend(finalPayload)
		print("Statistics: Sending Webhook...")
		local success, err = pcall(function()
			HttpService:PostAsync(WEBHOOK_URL, HttpService:JSONEncode(finalPayload))
		end)
		if not success then
			warn("Statistics: Webhook Failed:", err)
		else
			print("Statistics: Webhook Sent Successfully")
		end
	end
	
	local shouldGenerateImage = isTotal or string.find(title, "ATUALIZAÇÃO") or string.find(title, "FIM DO")
	
	if shouldGenerateImage then
		-- Async generation for stats image
		task.spawn(function()
			local html = GenerateMatchStatsHTML(dataScope)
			
			local success, response = pcall(function()
				return HttpService:RequestAsync({
					Url = "https://html2png.dev/api/convert",
					Method = "POST",
					Headers = { ["Content-Type"] = "text/html" },
					Body = html
				})
			end)
			
			if success and response.StatusCode == 200 then
				local json = HttpService:JSONDecode(response.Body)
				if json.success and json.url then
					print("Statistics: Image generated (" .. json.url .. ")")
					payload.embeds[1]["image"] = { ["url"] = json.url }
				else
					warn("Statistics: API returned success but no URL", response.Body)
				end
			else
				warn("Statistics: Failed to generate image via API: " .. tostring(success and response.StatusCode or response))
			end
			
			-- Se falhar a imagem, poderíamos adicionar texto como fallback, 
			-- mas o usuário pediu "Só a imagem". Se falhar, vai sem stats ou só com título.
			-- Para garantir que algo apareça se a imagem falhar, podemos adicionar texto APENAS se não tiver URL.
			
			local hasImage = (payload.embeds[1]["image"] ~= nil)
			
			if not hasImage and not skipStats and dataScope then
				-- Fallback: Adiciona texto se a imagem falhou
				local playerHeader = string.format("%s | RATING | G | A | CA | S | MIS | EF%% | STL | PAS | ERR\n%s", pad("JOGADOR", 4), string.rep("-", 60))
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
						if string.find(string.lower(teamName), "away") then color = "\27[1;31m" 
						elseif string.find(string.lower(teamName), "home") then color = "\27[1;34m" end
					end
					local reset = "\27[0m"
					table.insert(list, {Name = shortName, FullName = name, Stats = stats, Color = color, Reset = reset})
				end
				
				for _, item in ipairs(list) do
					local s = item.Stats
					local ef = (s.EficPct or 0) .. "%"
					local dp = (s.DefPct or 0) .. "%"
					local passes = (s.PassesCompleted or 0) .. "/" .. (s.PassesAttempted or 0)
					local rating = string.format("%.1f", s.Rating or 6.0)
					local misses = s.Misses or 0
					
					playerBody ..= string.format("%s%s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s%s\n",
						item.Color, pad(item.Name, 4), pad(rating, 6), pad(s.Goals or 0, 1), pad(s.Assists or 0, 1), pad(s.FastBreakGoals or 0, 2), pad(s.SOG or 0, 1), pad(misses, 3), pad(ef, 3), pad(s.Steals or 0, 3), pad(passes, 5), pad(s.Turnovers or 0, 3), item.Reset
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
			end
			
			doSend(payload)
		end)
		return -- Exit function, async task handles sending
	end

	-- Handling non-total updates (Goals, Halftime, etc) - Standard Sync Logic
	if not skipStats and dataScope then
		local playerHeader = string.format("%s | RATING | G | A | CA | S | MIS | EF%% | STL | PAS | ERR\n%s", pad("JOGADOR", 4), string.rep("-", 60))
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
			local pObj = Players:GetPlayerByUserId(tonumber(_)) -- BUG: _ is index 1,2,3 not UID. 
			-- FIX: We don't have UID here easily in sorted list. 
			-- Assuming CalculateDerivedStats was called before or doesn't strictly need pObj for basic checks except IsGK
			StatUtils.CalculateDerivedStats(s, nil) -- Passing nil, IsGK check handles missing pObj via TeamName

			local ef = (s.EficPct or 0) .. "%"
			local dp = (s.DefPct or 0) .. "%"
			local passes = (s.PassesCompleted or 0) .. "/" .. (s.PassesAttempted or 0)
			local rating = string.format("%.1f", s.Rating or 6.0)
			local misses = s.Misses or 0

			playerBody ..= string.format("%s%s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s%s\n",
				item.Color, pad(item.Name, 4), pad(rating, 6), pad(s.Goals or 0, 1), pad(s.Assists or 0, 1), pad(s.FastBreakGoals or 0, 2), pad(s.SOG or 0, 1), pad(misses, 3), pad(ef, 3), pad(s.Steals or 0, 3), pad(passes, 5), pad(s.Turnovers or 0, 3), item.Reset
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

	doSend(payload)
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
	
	-- Raposa: Recompensa de Moedas (Rating * 10)
	local PlayerModule = require(script.Parent.Player)
	for uid, stats in pairs(combined) do
		local player = Players:GetPlayerByUserId(tonumber(uid))
		if player then
			local rating = stats.Rating or 6.0
			local reward = math.floor(rating * 10)
			if reward > 0 then
				PlayerModule:AddCoins(player, reward)
				-- Notificar (pode ser via chat ou UI se houver sistema de notificação)
				-- Exemplo simples: print
				print(player.Name .. " ganhou " .. reward .. " moedas por Rating " .. rating)
			end
		end
	end
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
					sendToDiscord("?? ATUALIZAÇÃO - " .. halfLabel .. " - " .. tostring(minutes) .. " min", StatsData[CurrentHalf], false)
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

