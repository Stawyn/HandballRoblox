local Teams = game:GetService("Teams")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BlackListedTeams = {
	"Crowd",
	"Officials",
	"@Away Substitutes",
	"@Home Substitutes",
}

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Celebrations = Remotes:WaitForChild("Celebrations")

Celebrations.OnServerEvent:Connect(function(Player, Scorer, Og)
	
	
	if Og == true then
		
		for _, Player in pairs(Players:GetPlayers()) do

			if Player.Team ~= Scorer.Team then

				if table.find(BlackListedTeams, Scorer.Team.Name) then

					return
				end

				Player.PlayerGui.ShopGui.InventoryFrame.Visible = true
			end
		end
		
	else
		
		for _, Player in pairs(Players:GetPlayers()) do

			if Player.Team == Scorer.Team then

				if table.find(BlackListedTeams, Scorer.Team.Name) then

					return
				end

				Player.PlayerGui.ShopGui.InventoryFrame.Visible = true
			end
		end
	end	
	
	task.wait(4)
	
	for _, Player in pairs(Players:GetPlayers()) do

		Player.PlayerGui.ShopGui.InventoryFrame.Visible = false
	end
end)
