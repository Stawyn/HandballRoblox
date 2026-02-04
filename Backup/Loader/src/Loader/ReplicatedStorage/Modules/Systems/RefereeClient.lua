local Players = game:GetService("Players")

local ClientNetwork = require("../Implementation/ClientNetwork")
local RefereeEvent = ClientNetwork.RefereeEvent
local RefereeEventRemote = ClientNetwork.RefereeEventRemote

local localPlayer = Players.LocalPlayer :: Player

-- DATA STUFF
local data = workspace:WaitForChild("Core"):WaitForChild("Data") :: Folder
local awayName = data:WaitForChild("AwayName") :: StringValue
local homeName = data:WaitForChild("HomeName") :: StringValue
local ballTimer = data:WaitForChild("BallTimer") :: BoolValue
local matchPaused = data:WaitForChild("MatchPaused") :: BoolValue
local homeScoreNumberValue = data:WaitForChild("HomeScore") :: NumberValue
local awayScoreNumberValue = data:WaitForChild("AwayScore") :: NumberValue

-- REFEREE STUFF
local playerGui = localPlayer.PlayerGui
local refereeUI = playerGui:WaitForChild("RefereeUI", math.huge)
local refFrame = refereeUI:WaitForChild("MainFrame")
local awayFrame = refFrame:WaitForChild("AwayFrame")
local homeFrame = refFrame:WaitForChild("HomeFrame")


-- HOME TEAM STUFF
local homeAddGoal = homeFrame:WaitForChild("AddGoal") :: ImageButton
local homeRemoveGoal = homeFrame:WaitForChild("RemoveGoal") :: ImageButton
local homeTeamName = homeFrame:WaitForChild("NameTextBox") :: TextBox
local homeScore = homeFrame:WaitForChild("Score") :: TextLabel

-- AWAY TEAM STUFF
local awayAddGoal = awayFrame:WaitForChild("AddGoal") :: ImageButton
local awayRemoveGoal = awayFrame:WaitForChild("RemoveGoal") :: ImageButton
local awayTeamName = awayFrame:WaitForChild("NameTextBox") :: TextBox
local awayScore = awayFrame:WaitForChild("Score") :: TextLabel

-- TIMER/BALL TIMER STUFF
local timerFrame = refFrame:WaitForChild("TimerPanel"):WaitForChild("TimerFrame") :: Frame
local ballTimerStatus = refFrame:WaitForChild("TimerPanel"):WaitForChild("BallTimer"):WaitForChild("BallTimerStatus") :: ImageButton
local pause = timerFrame:WaitForChild("Pause") :: ImageButton
local reset = timerFrame:WaitForChild("Reset") :: ImageButton
local resume = timerFrame:WaitForChild("Resume") :: ImageButton

-- CONFIRMATION UI
local confirmationFrame = Instance.new("Frame")
confirmationFrame.Name = "ResetConfirmation"
confirmationFrame.Size = UDim2.new(0, 320, 0, 160)
confirmationFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
confirmationFrame.AnchorPoint = Vector2.new(0.5, 0.5)
confirmationFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
confirmationFrame.BorderSizePixel = 2
confirmationFrame.BorderColor3 = Color3.fromRGB(255, 255, 255)
confirmationFrame.Visible = false
confirmationFrame.ZIndex = 999
confirmationFrame.Parent = refereeUI

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = confirmationFrame

local confirmText = Instance.new("TextLabel")
confirmText.Size = UDim2.new(1, -40, 0, 70)
confirmText.Position = UDim2.new(0, 20, 0, 10)
confirmText.Text = "Deseja resetar o jogo?\nIsso irá limpar todas as estatísticas e placar."
confirmText.TextColor3 = Color3.new(1, 1, 1)
confirmText.TextWrapped = true
confirmText.BackgroundTransparency = 1
confirmText.Font = Enum.Font.SourceSansBold
confirmText.TextSize = 20
confirmText.ZIndex = 1000
confirmText.Parent = confirmationFrame

local yesButton = Instance.new("TextButton")
yesButton.Size = UDim2.new(0, 110, 0, 45)
yesButton.Position = UDim2.new(0.25, -55, 0.75, -22)
yesButton.Text = "SIM"
yesButton.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
yesButton.TextColor3 = Color3.new(1, 1, 1)
yesButton.Font = Enum.Font.SourceSansBold
yesButton.TextSize = 22
yesButton.ZIndex = 1000
yesButton.Parent = confirmationFrame
Instance.new("UICorner", yesButton).CornerRadius = UDim.new(0, 6)

local noButton = Instance.new("TextButton")
noButton.Size = UDim2.new(0, 110, 0, 45)
noButton.Position = UDim2.new(0.75, -55, 0.75, -22)
noButton.Text = "NÃO"
noButton.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
noButton.TextColor3 = Color3.new(1, 1, 1)
noButton.Font = Enum.Font.SourceSansBold
noButton.TextSize = 22
noButton.ZIndex = 1000
noButton.Parent = confirmationFrame
Instance.new("UICorner", noButton).CornerRadius = UDim.new(0, 6)

yesButton.MouseButton1Click:Connect(function()
	RefereeEvent:ResetMatch()
	confirmationFrame.Visible = false
end)

noButton.MouseButton1Click:Connect(function()
	confirmationFrame.Visible = false
end)

local function showResetConfirmation()
	confirmationFrame.Visible = true
	confirmationFrame:TweenPosition(UDim2.new(0.5, 0, 0.5, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.3, true)
end

-- Handle server-side confirmation requests (from ;reset command)
-- Connected early to ensure it works even if other parts of the script yield
RefereeEventRemote.OnClientEvent:Connect(function(data)
	if data and data.action == "SHOW_CONFIRM_RESET" then
		showResetConfirmation()
	end
end)

local DEACTIVATED_BALL_TIMER = {
	Image = "rbxassetid://8445519745",
	ImageRectOffset = Vector2.new(940, 784),
	ImageRectSize = Vector2.new(48, 48),
}
local ACTIVATED_BALL_TIMER = {
	Image = "rbxassetid://8445519745",
	ImageRectOffset = Vector2.new(4, 836),
	ImageRectSize = Vector2.new(48, 48),
}

-- IMPLEMENTATION
homeAddGoal.MouseButton1Click:Connect(function()
	RefereeEvent:AddGoal(true)
end)
awayAddGoal.MouseButton1Click:Connect(function()
	RefereeEvent:AddGoal(false)
end)

homeRemoveGoal.MouseButton1Click:Connect(function()
	RefereeEvent:RemoveGoal(true)
end)
awayRemoveGoal.MouseButton1Click:Connect(function()
	RefereeEvent:RemoveGoal(false)
end)

homeTeamName.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		RefereeEvent:ChangeTeamName(homeTeamName.Text, true)
	end
end)
awayTeamName.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		RefereeEvent:ChangeTeamName(awayTeamName.Text, false)
	end
end)

pause.MouseButton1Click:Connect(function()
	RefereeEvent:PauseMatch()
end)
resume.MouseButton1Click:Connect(function()
	if matchPaused.Value then
		RefereeEvent:ResumeMatch()
	else
		RefereeEvent:BeginLeague()
	end
end)
reset.MouseButton1Click:Connect(function()
	showResetConfirmation()
end)
ballTimerStatus.MouseButton1Click:Connect(function()
	RefereeEvent:ToggleBallTimer()
end)

-- UI UPDATE
function onBallTimerUpdateStatus()
	if ballTimer.Value then
		ballTimerStatus.Image = ACTIVATED_BALL_TIMER.Image
		ballTimerStatus.ImageRectOffset = ACTIVATED_BALL_TIMER.ImageRectOffset
		ballTimerStatus.ImageRectSize = ACTIVATED_BALL_TIMER.ImageRectSize
	else
		ballTimerStatus.Image = DEACTIVATED_BALL_TIMER.Image
		ballTimerStatus.ImageRectOffset = DEACTIVATED_BALL_TIMER.ImageRectOffset
		ballTimerStatus.ImageRectSize = DEACTIVATED_BALL_TIMER.ImageRectSize
	end
end
ballTimer:GetPropertyChangedSignal("Value"):Connect(onBallTimerUpdateStatus)
onBallTimerUpdateStatus()

function onScoreUpdate()
	homeScore.Text = tostring(homeScoreNumberValue.Value)
	awayScore.Text = tostring(awayScoreNumberValue.Value)
end
homeScoreNumberValue:GetPropertyChangedSignal("Value"):Connect(onScoreUpdate)
awayScoreNumberValue:GetPropertyChangedSignal("Value"):Connect(onScoreUpdate)
onScoreUpdate()
-- React to match paused state so the referee UI mirrors server-side pause/resume
local NETWORK_FOLDER = game:GetService("ReplicatedStorage"):WaitForChild("Network") :: Folder
local STATS_EVENT = NETWORK_FOLDER:WaitForChild("StatsUpdate") :: RemoteEvent

local HALF = data:WaitForChild("Half") :: NumberValue

function onMatchPausedUpdate()
	if matchPaused.Value then
		-- When paused, show resume prominently and disable pause button
		pause.Visible = false
		resume.Visible = true
		timerFrame.BackgroundTransparency = 0.5
	else
		-- When not paused, check if match is active
		if HALF.Value > 0 then
			pause.Visible = true
			resume.Visible = false
		else
			-- Match not started or ended, show Begin (resume button)
			pause.Visible = false
			resume.Visible = true
		end
		timerFrame.BackgroundTransparency = 0
	end
end
matchPaused:GetPropertyChangedSignal("Value"):Connect(onMatchPausedUpdate)
HALF:GetPropertyChangedSignal("Value"):Connect(onMatchPausedUpdate)
onMatchPausedUpdate()

-- Keep UI synced with statistics reset events (fired on server GameStatistics.Reset)
STATS_EVENT.OnClientEvent:Connect(function(action, ...)
	if action == "Reset" then
		-- Scores and other UI will be updated by value signals, but ensure visual state resets
		onScoreUpdate()
		onBallTimerUpdateStatus()
		-- clear paused state visuals
		if matchPaused.Value then
			onMatchPausedUpdate()
		end
	end
end)


return {}


