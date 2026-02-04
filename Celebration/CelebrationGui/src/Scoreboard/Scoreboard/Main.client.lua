local TweenService = game:GetService("TweenService")
local Info = TweenInfo.new(.05, 
	Enum.EasingStyle.Linear, 
	Enum.EasingDirection.In)

local mainFrame = script.Parent
local statsFolder: Folder = workspace:WaitForChild("Core"):WaitForChild("Stats")

local function HandleTimer(...)
	mainFrame.Timer.Text = statsFolder.Time.Value
end

local function HandleTeamName(...)
	mainFrame.HomeName.Text = statsFolder["Home Name"].Value
	mainFrame.AwayName.Text = statsFolder["Away Name"].Value
end

local function ET(...)
	if statsFolder.ET.Value > 0 then
		mainFrame.ET.Text = "+"..tostring(statsFolder.ET.Value)
		local Tween = TweenService:Create(mainFrame.ET, Info, {Position = UDim2.new(0.769, 0,0.88, 0)})
		Tween:Play()
	else
		mainFrame.ET.Text = "+0"
		local Tween = TweenService:Create(mainFrame.ET, Info, {Position = UDim2.new(0.593, 0,0.88, 0)})
		Tween:Play()
	end
end

local function HandleScores()
	mainFrame.Score.Text = ("%s - %s"):format(tostring(statsFolder.Scores.Home.Value), tostring(statsFolder.Scores.Away.Value))
end


statsFolder:WaitForChild("Scores"):WaitForChild("Home"):GetPropertyChangedSignal("Value"):Connect(HandleScores)
statsFolder:WaitForChild("Scores"):WaitForChild("Away"):GetPropertyChangedSignal("Value"):Connect(HandleScores)
statsFolder.Time:GetPropertyChangedSignal("Value"):Connect(HandleTimer)
statsFolder.ET:GetPropertyChangedSignal("Value"):Connect(ET)
statsFolder["Home Name"]:GetPropertyChangedSignal("Value"):Connect(HandleTeamName)
statsFolder["Away Name"]:GetPropertyChangedSignal("Value"):Connect(HandleTeamName)

HandleTimer()
ET()
HandleTeamName()
HandleScores()