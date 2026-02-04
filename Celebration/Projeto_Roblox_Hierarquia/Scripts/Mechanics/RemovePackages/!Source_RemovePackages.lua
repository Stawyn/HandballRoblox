local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player: Player)
	player.CharacterAppearanceLoaded:Connect(function(character: Model)
		for _, characterPart: BasePart in pairs(character:GetChildren()) do
			if characterPart:IsA("CharacterMesh") then
				characterPart:Destroy()
			end
		end
	end)
end)
