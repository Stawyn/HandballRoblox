local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer

local SoundGroup = SoundService.SoundGroup
local ClickSystem = SoundGroup.ClickSystem

local Sucess = ClickSystem.Success
local Close = ClickSystem.Close

local TopBar = require(ReplicatedStorage.Utils.Icon)
local Emotes = TopBar.new()
Emotes:setName("Settings")
Emotes:setImage("rbxassetid://11807308234")
Emotes:setOrder(3)
Emotes:bindEvent("selected", function()
	local EmotesUI = LocalPlayer.PlayerGui:WaitForChild("ShopGui").Window
	Sucess:Play()
	EmotesUI.Visible = true
end)
Emotes:bindEvent("deselected", function()
	local EmotesUI = LocalPlayer.PlayerGui:WaitForChild("ShopGui").Window
	Close:Play()
	EmotesUI.Visible = false
end)