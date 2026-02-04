local Teams = game:GetService("Teams")
local SSS = game:GetService("ServerScriptService")

local ABHLeague
if SSS:FindFirstChild("Modules") then
	if SSS.Modules:FindFirstChild("Implementation") then
		if SSS.Modules.Implementation:FindFirstChild("ABHLeague") then
			ABHLeague = require(SSS.Modules.Implementation.ABHLeague)
		end
	end
end

return function(_K)
	_K.Registry.registerCommand(_K, {
		name = "choose",
		aliases = { "pick" }, 
		description = "Team player(s) for your team. You must be chosen as a manager to use this.",

		
		group = "Default", 
		noLog = false, 
		args = {
			{
				type = "players",
				name = "Player(s) name",
				description = "Player(s) that will join your team.", 
				optional = false, 
			},
		},
		permissions = {}, 

		run = function(context, players)
			if not ABHLeague then
				return
			end

			local isHomeManager = ABHLeague.HomeTeamManagerUserId == context.fromPlayer.UserId
			local isAwayManager = ABHLeague.AwayTeamManagerUserId == context.fromPlayer.UserId

			if not isHomeManager and not isAwayManager then
				return
			end

			local targetTeam = isHomeManager and Teams["Home Team"] or Teams["Away Team"]

			for _, player in ipairs(players) do
				player.Team = targetTeam
			end
		end,
	})
end