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
		name = "sub",
		aliases = { },
		description = "Sub player(s) for your team. You must be choosen as a manager by the match referee to execute this command",

		group = "General",
		noLog = false, 
		args = {
			{
				type = "players",
				name = "Player(s) name",
				description = "Player(s) that will join be subbed for your team.", 
				optional = false, 
				permissions = {}, 
				lowerRank = false, 
				ignoreSelf = false, 
				shouldRequest = false, 
			},
		},
		permissions = {}, 

		run = function(context, players: {Player})
			if not ABHLeague then
				return
			end
			
			if ABHLeague.HomeTeamManagerUserId ~= context.from and ABHLeague.AwayTeamManagerUserId ~= context.from then
				return
			end
			
			local presumedTeam = if ABHLeague.HomeTeamManagerUserId == context.from then 
				Teams["@Home Substitutes"] 
			else
				Teams["@Away Substitutes"]
			
			for _, player in players do
				player.Team = presumedTeam
			end
		end,
	})
end