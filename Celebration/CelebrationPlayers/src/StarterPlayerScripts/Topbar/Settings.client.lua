local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")

local Topbar = require(ReplicatedStorage:WaitForChild("Utils"):WaitForChild("Icon"))
local SettingsController = require(ReplicatedStorage:WaitForChild("Controllers"):WaitForChild("SettingsController"))

local SoundGroup = SoundService.SoundGroup
local ClickSystem = SoundGroup.ClickSystem

local Sucess = ClickSystem.Success
local Close = ClickSystem.Close

local localPlayer: Player = Players.LocalPlayer

local settingsIcon = Topbar.new()
:setName("Settings")
:setImage("rbxassetid://7059346373")
:setOrder(1)

settingsIcon:bindEvent("selected", function()
	Sucess:Play()
	localPlayer.PlayerGui:WaitForChild("Settings UI").Enabled = true
end)
settingsIcon:bindEvent("deselected", function()
	Close:Play()
	localPlayer.PlayerGui:WaitForChild("Settings UI").Enabled = false
end)