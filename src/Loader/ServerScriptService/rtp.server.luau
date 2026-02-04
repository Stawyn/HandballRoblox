local Players = game:GetService("Players")

-- Bug #13: Referência para verificar se partida está ativa
local DATA_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Data")
local MATCH_BOOLEAN = DATA_FOLDER:WaitForChild("Match") :: BoolValue

local function refreshPlayer(player)
	-- Bug #13: Bloquear RTP durante partida ativa
	if MATCH_BOOLEAN.Value == true then
		-- Verificar se jogador está em time de jogo
		local teamName = player.Team and player.Team.Name or ""
		if teamName:find("Home") or teamName:find("Away") then
			warn("[RTP] Blocked during active match:", player.Name)
			return
		end
	end
	
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