local Players = game:GetService("Players")

function PlayerAdded(Player)
	local function RTP()
		
		local Character = Player.Character
		local LastCFrame = Character:GetPrimaryPartCFrame()
		
		if not Character then 
			return 
		end

		Player:LoadCharacter()
		Character = Player.Character
		Character:SetPrimaryPartCFrame(LastCFrame)
	end

	local function MSG(Message)
		if string.lower(Message) == "rtp" or string.lower(Message) == "re" then
			RTP(Player)
		end
	end
	
	Player.Changed:Connect(function(Property)
		if Property == "Team" then
			local Character = Player.Character
			if Character then
				Player:LoadCharacter()
			end
		end
	end)

	Player.Chatted:Connect(MSG)
end	

Players.PlayerAdded:Connect(PlayerAdded)
