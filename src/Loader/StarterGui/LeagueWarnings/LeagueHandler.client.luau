local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local Janitor = require(ReplicatedStorage:WaitForChild("Utilities"):WaitForChild("Janitor")) :: typeof(require(script.Parent.Parent.Parent.ReplicatedStorage.Utilities.Janitor))
local SharedTypes = require(ReplicatedStorage:WaitForChild("Utilities"):WaitForChild("SharedTypes")) :: typeof(require(script.Parent.Parent.Parent.ReplicatedStorage.Utilities.SharedTypes))
local Icon = require(ReplicatedStorage:WaitForChild("Utilities"):WaitForChild("Icon")) :: typeof(require(script.Parent.Parent.Parent.ReplicatedStorage.Utilities.Icon))

local BALLS_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Balls")
local NETWORK_FOLDER = ReplicatedStorage:WaitForChild("Network") :: Folder
local LEAGUE_EVENT = NETWORK_FOLDER:WaitForChild("LeagueEvent") :: RemoteEvent


local localPlayer = Players.LocalPlayer :: Player
local takeThrowTextLabel = script.Parent.Take
local warning = script.Parent.Warnings

function HandleRequestFT(ball: SharedTypes.ABHBallInstance)
	local forceField = ball:FindFirstChild("ForceField") :: BasePart
	if not forceField then
		return
	end
	if forceField:GetAttribute("Took") == true then
		return
	end

	local teamName = (localPlayer.Team :: Team).Name
	if teamName:find("Substitutes") then
		return
	end
	if forceField:GetAttribute("isHome") == true and not teamName:find("Home") then
		return
	end
	if forceField:GetAttribute("isHome") == false and not teamName:find("Away") then
		return
	end

	local takeText = takeThrowTextLabel:Clone()

	local throwJanitor = Janitor.new()
	throwJanitor:LinkToInstance(forceField)
	throwJanitor:Add(takeText, "Destroy")
	throwJanitor:Add(UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
		if gameProcessedEvent then
			return
		end
		if input.KeyCode ~= Enum.KeyCode.T then
			return
		end

		LEAGUE_EVENT:FireServer("TEAM_FREE_THROW_CLIENT", ball.Name)
	end), "Disconnect")
	throwJanitor:Add(forceField:GetAttributeChangedSignal("Took"):Connect(function()
		takeText.Visible = false
	end), "Disconnect")
	throwJanitor:Add(localPlayer:GetPropertyChangedSignal("Team"):Connect(function()
		throwJanitor:Destroy()
	end))

	takeText.Visible = true
	takeText.Parent = script.Parent
end

function onTeamChanged()
	for _, ball in BALLS_FOLDER:GetChildren() do
		task.spawn(HandleRequestFT, ball :: SharedTypes.ABHBallInstance)
	end
end

LEAGUE_EVENT.OnClientEvent:Connect(function(action, ...)
	if action == "TEAM_FREE_THROW_CLIENT" then
		local ballName = ... 
		local ball = BALLS_FOLDER:FindFirstChild(ballName)
		if not ball then
			return
		end

		coroutine.wrap(HandleRequestFT)(ball :: SharedTypes.ABHBallInstance)
	elseif action == "CALL_FOR_PAUSE" then
		local playerName = ...
		local clone = warning:Clone()
		clone.Text = string.format("%s pediu pausa técnica", playerName)
		clone.Visible = true 
		clone.Parent = script.Parent
		Debris:AddItem(clone, 7)
	elseif action == "POSSIBLE_PASSBACK" then
		local isHome = ... 
		local preusmedTeam = if isHome then "Casa" else "Visitante"
		local clone = warning:Clone()
		clone.Text = string.format("Possível recuo detectado do time %s", preusmedTeam)
		clone.Visible = true 
		clone.Parent = script.Parent
		Debris:AddItem(clone, 7)
	elseif action == "BALL_TIME_VIOLATION" then
		local playerName, message = ...
		local clone = warning:Clone()
		clone.Text = string.format("[%s] %s", playerName, message)
		clone.TextColor3 = Color3.fromRGB(255, 255, 255)
		clone.Visible = true 
		clone.Parent = script.Parent
		Debris:AddItem(clone, 7)
	end
end)

localPlayer:GetPropertyChangedSignal("Team"):Connect(onTeamChanged)
onTeamChanged()
