local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = ReplicatedStorage:WaitForChild("Remotes")
local MarkerEvent = RemoteEvents.Marker

local MarkerView = {
	{"Home", "-Home Goalkeeper", "@HSubs"},
	{"Away", "-Away Goalkeeper", "@ASubs"}
}

function CheckMarkerView(sender, viewer)
	
	local senderTeamName = sender.Team.Name
	local viewerTeamName = viewer.Team.Name
	
	if viewerTeamName == senderTeamName then
		return true
	else
		for _, team in pairs(MarkerView) do
			if table.find(team, senderTeamName) and table.find(team, viewerTeamName) then
				return true
			end
		end
	end
	return false
end

MarkerEvent.OnServerEvent:Connect(function(Player, Position)
	
	local Team = Player.TeamColor
	local TeamColor = Instance.new("Part")

	for _, v in pairs(game.Players:GetPlayers()) do
		if CheckMarkerView(Player, v) then
			TeamColor.BrickColor = Team
			MarkerEvent:FireClient(v, TeamColor.Color, Position, Player)
			TeamColor:Destroy()
		end
	end
end)
