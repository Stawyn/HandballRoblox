local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local MainFolder = ReplicatedStorage.Remotes

local PassMarker = {}

local Player = Players.LocalPlayer
local MarkerEvent = MainFolder.Marker

function PassMarker:Marker(Position, Colour)
	
	local MarkersFolder = ReplicatedStorage.Markers
	local MarkerMain = MarkersFolder.Main
	local PassMarker = MarkerMain.PassMarker
	
	MarkerEvent:FireServer(Position, Colour)

	local ClientMarker = PassMarker:Clone()
	
	ClientMarker.Config.MarkerColor.Value = Colour
	ClientMarker.Config.SenderName.Value = Player.Name
	ClientMarker.Config.SenderId.Value = Player.UserId
	ClientMarker.CFrame = CFrame.new(Position + Vector3.new(0, 8, 0))
	ClientMarker.Parent = game.ReplicatedStorage.Markers

	game:GetService("Debris"):AddItem(ClientMarker, 2)
end

return PassMarker