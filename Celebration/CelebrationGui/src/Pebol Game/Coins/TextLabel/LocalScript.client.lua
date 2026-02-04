local Players = game:GetService("Players")

local Player = Players.LocalPlayer

local Leaderstats = Player:WaitForChild("leaderstats")
local Coins = Leaderstats:WaitForChild("Coins")

Coins:GetPropertyChangedSignal("Value"):Connect(function()
	
	script.Parent.Text = Coins.Value
end)