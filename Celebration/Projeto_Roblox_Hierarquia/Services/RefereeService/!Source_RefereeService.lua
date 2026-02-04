local RefereeService = {}

local TimerModule = require(script:WaitForChild("TimerModule"))

local MatchValues: {string} = {"Training", "Scrim", "Friendly", "League", "Cup", "Important Match", "Final Match"}

local matchStats: Folder = workspace:WaitForChild("Core"):WaitForChild("Stats")
local statEvent: BindableEvent = game:GetService("ServerScriptService"):WaitForChild("ServerRemote"):WaitForChild("StatEvent")

type SetGoalProperties = {
	add: boolean,
	isHome: boolean
}

type SetAbbreviationProperties = {
	abbreviation: string,
	isHome: boolean
}

function RefereeService:SetMatchValue(value: string)
	if not table.find(MatchValues, value) then return end
	matchStats.Match.Value = value
end

function RefereeService:SetGoal(properties: SetGoalProperties)
	if properties.add then
		if properties.isHome then
			matchStats.Scores.Home.Value += 1
		else
			matchStats.Scores.Away.Value += 1
		end
	else
		if properties.isHome then
			matchStats.Scores.Home.Value -= 1
		else
			matchStats.Scores.Away.Value -= 1
		end
	end
end

function RefereeService:SetTimerState(state: boolean)
	if state then
		TimerModule:Resume()
	else
		TimerModule:Pause()
	end
end

function RefereeService:SetET(value: number)
	if not tonumber(value) then return end
	if tonumber(value) > 4 then return end
	matchStats.ET.Value = tonumber(value)
end

function RefereeService:ResetET()
	matchStats.ET.Value = 0
end

function RefereeService:ResetScores()
	matchStats.Scores.Home.Value = 0
	matchStats.Scores.Away.Value = 0
end

function RefereeService:ResetTimer()
	TimerModule:Reset()
end

function RefereeService:SetAbbreviation(properties: SetAbbreviationProperties)
	local fourLettersName: string = properties.abbreviation:sub(1, 4)
	if properties.isHome then
		matchStats["Home Name"].Value = fourLettersName
	else
		matchStats["Away Name"].Value = fourLettersName
	end
end

return RefereeService

