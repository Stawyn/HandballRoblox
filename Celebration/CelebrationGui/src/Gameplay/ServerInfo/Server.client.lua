local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MainFolder = ReplicatedStorage.RemoteFunctions

local ServerInfo = MainFolder.PlaceInfo:InvokeServer("Server")

script.Parent.Text = "Server: "..ServerInfo