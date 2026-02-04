local Teams = game:GetService("Teams")

local HomeGk = Teams:WaitForChild("-Home Goalkeeper")
local AwayGk = Teams:WaitForChild("-Away Goalkeeper")

function CheckHome(Player)
	
	if #HomeGk:GetPlayers() > 1 then
		
		Player.Team = Teams:WaitForChild("Home")
	end
end

function CheckAway(Player)
	
	if #AwayGk:GetPlayers() > 1 then
		
		Player.Team = Teams:WaitForChild("Away")
	end
end

HomeGk.PlayerAdded:Connect(CheckHome)
AwayGk.PlayerAdded:Connect(CheckAway)
