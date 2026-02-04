--[[

ADMIN POWERS

0		Player
1		VIP/Donor
2		Moderator
3		Administrator
4		Super Administrator
5		Owner
6		Game Creator

First table consists of the different variations of the command.

Second table consists of the description and an example of how to use it.

Third index is the ADMIN POWER required to use the command.

Fourth table consists of the arguments that will be returned in the args table.
'player'	-- returns an array of Players
'userid'	-- returns an array of userIds
'boolean'	-- returns a Boolean value
'color'		-- returns a Color3 value
'number'	-- returns a Number value
'string'	-- returns a String value
'time'		-- returns # of seconds
'banned'	-- returns a value from Bans table
'admin'		-- returns a value from Admins table
-- Adding / to any argument will make it optional; can return nil!!!

Fifth index consists of the function that will run when the command is executed properly.	]]
return {

	{{'test','othertest'},{'Test command.','Example'},5,{'number','string/'},function(pl,args)
		print(pl,args[1],args[2])
	end},
	{
		{"autoteam", "autotm"}, {"Automatically team every player based on their team.", "team(name) side(home/away)"},
		2,
		{"string"},
		function(player: Player, args: {string | number})
			local arguments: string = string.split(args[1], " ")			
			local playersToTeam: {Player} = {}
			local sideToTeam: Team
			local teamName = string.lower(arguments[1])
			local sideSelected = string.lower(arguments[2])

			for index, player in pairs(game:GetService("Players"):GetPlayers()) do
				if not player:FindFirstChild("leaderstats") or not player.leaderstats:FindFirstChild("Team") then continue end
				local playerTeam: string = string.lower(player.leaderstats.Team.Value)
				if playerTeam:find("^"..teamName) then
					table.insert(playersToTeam, player)
				end
			end

			for index, team in pairs(game:GetService("Teams"):GetTeams()) do
				if string.lower(team.Name):find("^"..sideSelected) then
					sideToTeam = team
				end
			end

			if sideToTeam == nil then
				return error("No team named "..arguments[2].." found")
			end

			for index, player in pairs(playersToTeam) do
				player.Team = sideToTeam
			end
		end,
	},
	{
		{"randomsubstitute", "randomsub"}, {"Randomly teams a player substitute", "randomsubstitute side(home/away amount)"},
		2,
		{"string", "number"},
		function (player: Player, args: {string})
			local arguments: string = string.split(args[1], " ")	
			local sideSelected = string.lower(arguments[1])
			local amount: number | string = tonumber(arguments[2])
			local foundTeam: Team

			for index, team in pairs(game:GetService("Teams"):GetTeams()) do
				if string.lower(team.Name):find("^"..sideSelected) then
					foundTeam = team
				end
			end

			if not foundTeam then
				return error("No team named "..sideSelected.." found")
			elseif foundTeam.Name ~= "Home" and foundTeam.Name ~= "Away" then
				return error("Team side must be away or home")
			end

			local function SubPlayer()
				local teamPlayers = foundTeam:GetPlayers()
				local playerGettingSubbed = math.random(1, #teamPlayers)
				local subTeamString = "@%s Substitutes"
				subTeamString = subTeamString:format(foundTeam.Name)
				teamPlayers[playerGettingSubbed].Team = game:GetService("Teams")[subTeamString]
			end

			for i = 1, amount do
				SubPlayer()
			end

		end,
	},
};
