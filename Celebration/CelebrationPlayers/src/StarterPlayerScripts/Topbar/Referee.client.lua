local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Topbar = require(ReplicatedStorage:WaitForChild("Utils"):WaitForChild("Icon"))
local Maid = require(ReplicatedStorage:WaitForChild("Utils"):WaitForChild("Maid"))

local localPlayer: Player = Players.LocalPlayer

local studsString = "GAME"

local infoIcon = Topbar.new()
	:setName("PingTopBar")
	:setLabel("STUDS")
	:setOrder(999)
	:lock()

local gameInformation = ReplicatedStorage:WaitForChild("GameInfo"):WaitForChild("Message")
infoIcon:setLabel(gameInformation.Value)
gameInformation:GetPropertyChangedSignal("Value"):Connect(function()
	infoIcon:setLabel(gameInformation.Value)
end)