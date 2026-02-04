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
		name = "setawaymanager",
		aliases = { "setam", "setamanager" },
		description = "Choose the away team manager. You must me the match referee to execute this command",

		group = "General",
		noLog = false, 
		args = {
			{
				type = "player",
				name = "Player name",
				description = "The manager", 
				optional = false, 
				permissions = {}, 
				lowerRank = false, 
				ignoreSelf = false, 
				shouldRequest = false, 
			},
		},
		permissions = {
			
		}, 

		run = function(context, player: Player)
			if not ABHLeague then
				return
			end
			if context.fromPlayer.Team.Name ~= "Officials" then
				return
			end
			
			ABHLeague:SetAwayTeamManagerUserId(player.UserId)
		end,
	})
end