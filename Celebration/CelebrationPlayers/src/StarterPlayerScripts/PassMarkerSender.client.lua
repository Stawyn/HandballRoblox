local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local WorkSpace = game:GetService("Workspace")

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

local MainFolder = ReplicatedStorage.Remotes
local MarkerEvent = MainFolder.Marker

MarkerEvent.OnClientEvent:Connect(function(Color, Position, Sender)
	
	if Player.Name == Sender.Name then 
		return 
	end
	
	local MarkersFolder = ReplicatedStorage.Markers
	local MarkerMain = MarkersFolder.Main
	local PassMarker = MarkerMain.PassMarker
	
	local PassMarkerMain = PassMarker:Clone()
	
	PassMarkerMain.Config.MarkerColor.Value = Color
	PassMarkerMain.Config.SenderName.Value = Sender.Name
	PassMarkerMain.Config.SenderId.Value = Sender.UserId
	PassMarkerMain.CFrame = CFrame.new(Position + Vector3.new(0, 8, 0));
	PassMarkerMain.Parent = ReplicatedStorage.Markers
	
	Debris:AddItem(PassMarkerMain, 2)
end)