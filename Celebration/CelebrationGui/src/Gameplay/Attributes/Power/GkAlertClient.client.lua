local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local GAMEINFO_FOLDER = ReplicatedStorage:WaitForChild("GameInfo")

local gameMessage = GAMEINFO_FOLDER.Message
local Keeper = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Keeper")

function CheckGoalkeeperAvailability()
	if not gameMessage.Value:find("progress") then return end	
	if not Player.Team.Name:find("Home") and not Player.Team.Name:find("Away") then return end
	local playerTeam = Player.Team.Name:find("Home") and "Home" or "Away"
	local goalkeeperTeam = "-"..playerTeam.." Goalkeeper"
	
	if #Teams[goalkeeperTeam]:GetPlayers() < 1 then
		script.Parent.GkAlert.Visible = true
	else
		script.Parent.GkAlert.Visible = false
	end
end

gameMessage:GetPropertyChangedSignal("Value"):Connect(function()
	if not gameMessage.Value:find("progress") then return end
	CheckGoalkeeperAvailability()
end)

function HandlePlayers(instance: Team)
	instance.PlayerAdded:Connect(CheckGoalkeeperAvailability)
	instance.PlayerRemoved:Connect(CheckGoalkeeperAvailability)
end

Players.PlayerAdded:Connect(CheckGoalkeeperAvailability)
Players.PlayerRemoving:Connect(CheckGoalkeeperAvailability)

HandlePlayers(Teams["-Home Goalkeeper"])
HandlePlayers(Teams["-Away Goalkeeper"])
CheckGoalkeeperAvailability()

if UserInputService.TouchEnabled then
	script.Parent.GkAlert.Text = "GK available, touch here to change"
	script.Parent.GkAlert.MouseButton1Click:Connect(function()
		Keeper:FireServer("Keeper")
	end)
end