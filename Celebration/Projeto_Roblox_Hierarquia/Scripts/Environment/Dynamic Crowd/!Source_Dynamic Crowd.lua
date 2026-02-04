local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local CrowdModule = require(script.CrowdModule)

CrowdModule:ResetCrowdTexture()
CrowdModule:SetBasePercentageAndPopulate(0)


local matchStats: Folder = workspace:WaitForChild("Core"):WaitForChild("Stats")
local matchValue: StringValue = matchStats:WaitForChild("Match")

local MatchValues = {
	"Training", 
	"Scrim", 
	"Friendly", 
	"League", 
	"Cup", 
	"Important Match", 
	"Final Match",
}

local ratingIncrement = 2 / (#MatchValues - 1)
for i, value in ipairs(MatchValues) do
	local rating = (i - 1) * ratingIncrement 
	MatchValues[i] = {value = value, rating = rating}
end

function GetRatingForMatchValue(matchValue)
	for _, entry in ipairs(MatchValues) do
		if entry.value == matchValue then
			return entry.rating
		end
	end
	return 1
end

function UpdateSound()
	local volume = (CrowdModule:GetPercentage() / 100) * 2
	for _, sound: Sound in pairs(SoundService:WaitForChild("Crowd"):GetChildren()) do
		if not sound:IsA("Sound") then continue end
		if sound.Name == "Crowd" then
			if not sound.IsPlaying and matchValue.Value ~= "Training" then sound:Play() end
			TweenService:Create(sound, TweenInfo.new(30), { Volume = volume }):Play()
		else
			TweenService:Create(sound, TweenInfo.new(30), { Volume = volume/1.25 }):Play()
		end
	end
end

function UpdateCrowdBasedOnPlayers()
	local MaximumAmmount = Players.MaxPlayers
	local CurrentMatchRating = 1
	
	local CurrentPercentage = #Players:GetPlayers() / MaximumAmmount
	CurrentPercentage *= CurrentMatchRating
	CurrentPercentage = math.clamp(CurrentPercentage, 0, 100)
	
	CrowdModule:SetBasePercentageAndPopulate(CurrentPercentage)
	UpdateSound()
end

for i, v in pairs(Players:GetPlayers()) do
	task.spawn(UpdateCrowdBasedOnPlayers, v)
end
Players.PlayerAdded:Connect(UpdateCrowdBasedOnPlayers)
Players.PlayerRemoving:Connect(UpdateCrowdBasedOnPlayers)
matchStats:WaitForChild("Match"):GetPropertyChangedSignal("Value"):Connect(UpdateCrowdBasedOnPlayers)
