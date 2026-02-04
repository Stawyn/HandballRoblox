type StatsProperties = {
	scorer: string,
	assist: string?,
	team: string,
	ownGoal: boolean,
	gltName: string
}

local HTTPService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local AutoService = require(ServerScriptService:WaitForChild("Services"):WaitForChild("AutoService"))
local SoundModuleService = require(ServerScriptService:WaitForChild("Services"):WaitForChild("SoundModuleService"))

local statsFolder: Folder = workspace:WaitForChild("Core"):WaitForChild("Stats")
local statEvent: BindableEvent = ServerScriptService:WaitForChild("ServerRemote"):WaitForChild("StatEvent")
local scoredEvent: RemoteEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Scored")

function HandleCoins(scorer: Player?, assister: Player?, og: boolean)
	if og then return end
	local presumedTeam = scorer.Team.Name:find("Home") and "Home" or "Away"
	
	if scorer then
		local coins = scorer:WaitForChild("leaderstats"):WaitForChild("Coins")
		coins.Value += 100
	end
	if assister and assister.Team.Name:find(presumedTeam) then
		local coins = assister:WaitForChild("leaderstats"):WaitForChild("Coins")
		coins.Value += 50
	end
end

function CreateStats(properties: StatsProperties)
	if properties.gltName == "Home" then
		statsFolder.Scores.Away.Value += 1
	else
		statsFolder.Scores.Home.Value += 1
	end
	
	if statsFolder.Match.Value == "Training" then return end
	
	task.spawn(HandleCoins, properties.scorer, properties.assist, properties.ownGoal)
	SoundModuleService:Play(SoundService.Crowd.Goal)
	scoredEvent:FireAllClients(properties.scorer, properties.assist, properties.ownGoal)
	AutoService:HandleGoal(properties.gltName)
end

function RefereeGoal(team: "Home" | "Away")
	local index: number = #statsFolder[team.." Scorers"]:GetChildren() +1
	local template: StringValue = script.Template:Clone()
	template.Value = statsFolder.Time.Value
	template.Name = "["..index.."]".." Goal added by the referee - "..template.Value
	
	template.Parent = statsFolder[team.." Scorers"]
end

function UpdateHomeIndex()
	for index: number, value: StringValue in pairs(statsFolder["Home Scorers"]:GetChildren()) do
		local currentName = value.Name
		local newIndex = "[" .. index .. "]"
		local updatedName, count = currentName:gsub("%[%d+%]", newIndex)
		value.Name = updatedName
	end
end

function UpdateAwayIndex()
	for index: number, value: StringValue in pairs(statsFolder["Away Scorers"]:GetChildren()) do
		local currentName = value.Name
		local newIndex = "[" .. index .. "]"
		local updatedName, count = currentName:gsub("%[%d+%]", newIndex)
		value.Name = updatedName
	end
end

statsFolder["Home Scorers"].ChildRemoved:Connect(function(child)
	UpdateHomeIndex()
end)
statsFolder["Home Scorers"].ChildAdded:Connect(function(child)
	UpdateHomeIndex()
end)
statsFolder["Away Scorers"].ChildRemoved:Connect(function(child)
	UpdateAwayIndex()
end)
statsFolder["Away Scorers"].ChildAdded:Connect(function(child)
	UpdateAwayIndex()
end)

statEvent.Event:Connect(function(event, ...)
	if event == "Goal" then
		local goalProperties: StatsProperties = ...
		CreateStats(goalProperties)
	elseif event == "Add Goal" then
		local team: string = ...
		RefereeGoal(team)
	end
end)
