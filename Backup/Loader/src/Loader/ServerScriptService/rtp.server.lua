local Players = game:GetService("Players")

local function refreshPlayer(player)
	local character = player.Character
	local oldCFrame = nil

	if character and character:FindFirstChild("HumanoidRootPart") then
		oldCFrame = character.HumanoidRootPart.CFrame
	end

	player:LoadCharacter()

	if oldCFrame then
		task.defer(function()
			local newChar = player.Character or player.CharacterAdded:Wait()
			local hrp = newChar:WaitForChild("HumanoidRootPart", 5)
			if hrp then
				hrp.CFrame = oldCFrame
			end
		end)
	end
end

Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		if message:lower() == "rtp" then
			refreshPlayer(player)
		end
	end)
end)