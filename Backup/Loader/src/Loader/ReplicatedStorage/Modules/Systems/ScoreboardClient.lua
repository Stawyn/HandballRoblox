local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local DATA = workspace:WaitForChild("Core"):WaitForChild("Data")
local NETWORK_FOLDER = game:GetService("ReplicatedStorage"):WaitForChild("Network") :: Folder
local STATS_EVENT = NETWORK_FOLDER:WaitForChild("StatsUpdate") :: RemoteEvent

-- Optional values we use to determine match status
local HALF = DATA:FindFirstChild("Half")
local MATCH_PAUSED = DATA:FindFirstChild("MatchPaused")

local localPlayer = Players.LocalPlayer :: Player
local playerGui = localPlayer.PlayerGui
local scoreboardUI = playerGui:WaitForChild("Scoreboard", math.huge):WaitForChild("Scoreboard", math.huge)

local UserInputService = game:GetService("UserInputService")
scoreboardUI.Active = true
scoreboardUI.Selectable = true

local dragToggle = false
local dragStart = nil
local startPos = nil

scoreboardUI.InputBegan:Connect(function(input)
	if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		dragToggle = true
		dragStart = input.Position
		startPos = scoreboardUI.Position
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		if dragToggle then
			local delta = input.Position - dragStart
			local position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
			TweenService:Create(scoreboardUI, TweenInfo.new(0.08, Enum.EasingStyle.Sine), {Position = position}):Play()
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		dragToggle = false
	end
end)

-- Find or create a label to show match state (ABH - 1T / 2T / Pausado / Resetado)
local matchLabel = scoreboardUI:FindFirstChild("Match") or scoreboardUI:FindFirstChild("MatchText") or scoreboardUI:FindFirstChild("MatchLabel")
if not matchLabel then
	-- Create a simple unobtrusive label near the score if none exists
	matchLabel = Instance.new("TextLabel")
	matchLabel.Name = "Match"
	matchLabel.Size = UDim2.new(0, 150, 0, 20)
	matchLabel.BackgroundTransparency = 1
	matchLabel.TextColor3 = Color3.fromRGB(255,255,255)
	matchLabel.Font = Enum.Font.GothamBold
	matchLabel.TextSize = 14
	matchLabel.Text = ""
	-- position above the score text by default
	matchLabel.Position = UDim2.new(0.5, -75, 0, -25)
	matchLabel.Parent = scoreboardUI
end

local function updateMatchLabel()
	local status = ""
	local halfVal = HALF and HALF.Value or 0
	local paused = MATCH_PAUSED and MATCH_PAUSED.Value or false

	if paused then
		status = "ABH - Pausado"
	elseif halfVal == 1 then
		status = "ABH - 1T"
	elseif halfVal == 2 then
		status = "ABH - 2T"
	elseif halfVal == 0 then
		status = "ABH"
	else
		status = "ABH"
	end

	matchLabel.Text = status
end

if HALF then HALF:GetPropertyChangedSignal("Value"):Connect(updateMatchLabel) end
if MATCH_PAUSED then MATCH_PAUSED:GetPropertyChangedSignal("Value"):Connect(updateMatchLabel) end
STATS_EVENT.OnClientEvent:Connect(function(action, ...)
	if action == "Reset" then
		matchLabel.Text = "ABH - Resetado"
	end
end)

-- Initialize on load
updateMatchLabel()

local ET_VISIBLE_POS = UDim2.new(1, 5, 0, 0)
local ET_INVIS_POS = UDim2.new(1, -35, 0, 0)

function onNamesUpdate()
	local homeName = DATA.HomeName.Value
	local awayName = DATA.AwayName.Value

	scoreboardUI.HomeName.Text = homeName
	scoreboardUI.AwayName.Text = awayName
end

onNamesUpdate()
DATA.HomeName:GetPropertyChangedSignal("Value"):Connect(onNamesUpdate)
DATA.AwayName:GetPropertyChangedSignal("Value"):Connect(onNamesUpdate)

function onScoreUpdated()
	local homeScore = DATA.HomeScore.Value
	local awayScore = DATA.AwayScore.Value

	scoreboardUI.Score.Text = string.format("%d - %d", homeScore, awayScore)
end

onScoreUpdated()
DATA.HomeScore:GetPropertyChangedSignal("Value"):Connect(onScoreUpdated)
DATA.AwayScore:GetPropertyChangedSignal("Value"):Connect(onScoreUpdated)

function onTimerChanged()
	local currentSeconds = DATA.Timer.Value

	local minutes = math.floor(currentSeconds / 60)
	local seconds = currentSeconds % 60

	scoreboardUI.Timer.Text = string.format("%02d:%02d", minutes, seconds)
end

onTimerChanged()
DATA.Timer:GetPropertyChangedSignal("Value"):Connect(onTimerChanged)

function onETChanged()
	local isLA = DATA.LastAttack.Value
	local addedTIme = DATA.AddedTime.Value / 60

	if isLA then
		scoreboardUI.ET.Text = "LA"
		TweenService:Create(scoreboardUI.ET, TweenInfo.new(.1), {
			Position = ET_VISIBLE_POS,
			BackgroundTransparency = 0,
			TextTransparency = 0
		}):Play()
	elseif not isLA and addedTIme > 0 then
		scoreboardUI.ET.Text = "+"..tostring(addedTIme)
		TweenService:Create(scoreboardUI.ET, TweenInfo.new(.1), {
			Position = ET_VISIBLE_POS,
			BackgroundTransparency = 0,
			TextTransparency = 0
		}):Play()
	else
		TweenService:Create(scoreboardUI.ET, TweenInfo.new(.1), {
			Position = ET_INVIS_POS,
			BackgroundTransparency = 1,
			TextTransparency = 1
		}):Play()
	end
end

onETChanged()
DATA.LastAttack:GetPropertyChangedSignal("Value"):Connect(onETChanged)
DATA.AddedTime:GetPropertyChangedSignal("Value"):Connect(onETChanged)

return {}

