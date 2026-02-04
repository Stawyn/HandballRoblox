local Teams = game:GetService("Teams")

local cardSystem = {}
cardSystem.Players = {}

function cardSystem:AddPlayer(player)
	if not self.Players[player.UserId] then
		self.Players[player.UserId] = {
			player = player,
			hasYellow = false,
			hasRed = false,
			yellowCards = 0,
			redCardSeconds = 0,
			redFunction = nil,
			originalTeam = nil,
		}
	end
end

function cardSystem:GetData(player)
	return self.Players[player.UserId]
end

function cardSystem:ApplyCardGui(player, text, color3)
	if not player.Character then return end

	local head = player.Character:FindFirstChild("Head")
	if not head then return end

	if not head:FindFirstChild("CardGui") then 
		local playerCardGui = script.CardGui:Clone()
		playerCardGui.Parent = head
		playerCardGui.TextLabel.Text = text
		playerCardGui.TextLabel.TextColor3 = color3
	else
		local playerCardGui = head.CardGui
		playerCardGui.TextLabel.Text = text
		playerCardGui.TextLabel.TextColor3 = color3
	end
end

function cardSystem:RemovePlayerCards(player)
	self:AddPlayer(player)

	local playerData = self.Players[player.UserId]

	playerData.hasRed = false
	playerData.hasYellow = false
	playerData.yellowCards = 0
	playerData.redCardSeconds = 0

	if not player.Character then return end

	local head = player.Character:FindFirstChild("Head")

	if head and head:FindFirstChild("CardGui") then
		head.CardGui:Destroy()
	end
end

function cardSystem:GiveRed(player)
	self:AddPlayer(player)

	local playerData = self.Players[player.UserId]

	if playerData.hasRed then return end

	playerData.originalTeam = player.Team
	self:RemovePlayerCards(player)

	playerData.hasRed = true
	playerData.redCardSeconds = 120
	player.Team = Teams.Lobby

	if playerData.redFunction then
		task.cancel(playerData.redFunction)
	end

	playerData.redFunction = task.spawn(function()

		while playerData.redCardSeconds > 0 and playerData.hasRed do
			task.wait(1)
			playerData.redCardSeconds -= 1

			self:ApplyCardGui(player, tostring(playerData.redCardSeconds), Color3.fromRGB(255,0,0))
		end

		local wasExpelled = playerData.hasRed
		playerData.hasRed = false
		playerData.redCardSeconds = 0

		-- Retorna o jogador para o time original e teletransporta para o meio
		if wasExpelled and playerData.originalTeam and playerData.originalTeam.Parent then
			player.Team = playerData.originalTeam
			task.defer(function()
				if player.Character then
					player.Character:PivotTo(CFrame.new(0, 5, 0)) -- Meio da quadra
				end
			end)
		end

		-- Remove o Gui + cartões do jogador após ter finalizado os 120 segundos
		self:RemovePlayerCards(player)
	end)
end

function cardSystem:GiveYellow(player)
	self:AddPlayer(player)

	local playerData = self.Players[player.UserId]

	if playerData.hasRed then return end

	playerData.yellowCards += 1 
	playerData.hasYellow = true

	self:ApplyCardGui(player, "YC", Color3.fromRGB(255, 255, 0))

	if playerData.yellowCards >= 2 then
		self:GiveRed(player)
	end
end

function cardSystem:OnCharacterAdded(player)
	self:AddPlayer(player)

	local playerData = self.Players[player.UserId]

	if playerData.hasRed and playerData.redCardSeconds > 0 then
		self:ApplyCardGui(player, tostring(playerData.redCardSeconds), Color3.fromRGB(255,0,0))

	elseif playerData.hasYellow then
		self:ApplyCardGui(player, "YC", Color3.fromRGB(255,255,0))
	end
end

function cardSystem:ResetAll()
	for userId, playerData in self.Players do
		if playerData.redFunction then
			task.cancel(playerData.redFunction)
			playerData.redFunction = nil
		end

		local player = playerData.player
		if player and player.Parent then
			self:RemovePlayerCards(player)

			-- If player was in Lobby due to red card, return them
			if playerData.hasRed and playerData.originalTeam and playerData.originalTeam.Parent then
				player.Team = playerData.originalTeam
				task.defer(function()
					if player.Character then
						player.Character:PivotTo(CFrame.new(0, 5, 0)) -- Meio da quadra
					end
				end)
			end
		end
	end
	self.Players = {}
end

return cardSystem

