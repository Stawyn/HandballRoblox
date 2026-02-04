local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorkSpace = game:GetService("Workspace")

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

local Module = require(ReplicatedStorage.Markers.PassMarkerModule)

local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")

local Animations = ReplicatedStorage.Animations
local PassRequestFrame = Animations.PassRequest

local PassRequest = Humanoid.Animator:LoadAnimation(PassRequestFrame)

local Debounce = false

UserInputService.InputBegan:Connect(function(InputObject, GameProcessedEvent)
	if GameProcessedEvent then
		return
	end
	
	if InputObject.KeyCode == Enum.KeyCode.C then
		if Debounce == false then
			if Player.Team.Name ~= "Crowd" then
				if not Character:FindFirstChild("BallWeld") then
			
		            Debounce = true
			
		            local Target = Mouse.Target
		            local Sender = Player
		            local Part = Instance.new("Part")
		
		            Part.BrickColor = Player.TeamColor
 
		            local Color = Part.Color

			        Module:Marker(Vector3.new(Mouse.Hit.Position.X, 0, Mouse.Hit.Position.Z), Color)
				
                    PassRequest:Play()
			        Part:Destroy()
			        task.wait(2)
			
					Debounce = false
				end
			end
		end
	end
end)