local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerMouse = localPlayer:GetMouse()
local tool = script.Parent
local cardEvent = tool:waitForChild("RemoteEvent")

tool.Equipped:Connect(function(mouse)
	mouse.Button1Down:Connect(function()
		local target = playerMouse.Target
		if target.Parent.className == "Model" then
			cardEvent:FireServer(target)
		else
			cardEvent:FireServer(target.Parent)
		end
	end)

	mouse.Button2Down:Connect(function()
		local target = playerMouse.Target
		if target.Parent.className == "Model" then
			cardEvent:FireServer(target, "Remove")
		else
			cardEvent:FireServer(target.Parent, "Remove")
		end
	end)
end)