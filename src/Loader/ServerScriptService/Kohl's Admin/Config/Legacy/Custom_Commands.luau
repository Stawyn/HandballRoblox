NOTE = [[
	Legacy custom commands are automatically registered in the new admin!
]]

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
	{
		{ "softrestart", "refreshserver", "rejoinall" },
		{ "Faz todos reentrarem no servidor e atualiza o servidor mantendo o estado da partida.", ";softrestart" },
		5,
		{ "string/" },
		function(pl, args)
			local TeleportService = game:GetService("TeleportService")
			local Players = game:GetService("Players")
			local ServerScriptService = game:GetService("ServerScriptService")
			local ABHLeague = require(ServerScriptService.Modules.Implementation.ABHLeague)
			local DATA_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Data")

			-- Raposa: Pausar a partida antes de salvar o estado
			if DATA_FOLDER.Match.Value then
				ABHLeague:PauseMatch()
			end

			local data = {
				Match = DATA_FOLDER.Match.Value,
				Timer = DATA_FOLDER.Timer.Value,
				HomeScore = DATA_FOLDER.HomeScore.Value,
				AwayScore = DATA_FOLDER.AwayScore.Value,
				Half = DATA_FOLDER.Half.Value,
				HomeName = DATA_FOLDER.HomeName.Value,
				AwayName = DATA_FOLDER.AwayName.Value,
				AddedTime = DATA_FOLDER.AddedTime.Value,
				MatchPaused = if DATA_FOLDER.Match.Value then true else false,
				PlayerTeams = {},
				PlayerPositions = {},
				BallsData = {}
			}

			local BALLS_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Balls")
			for _, ball in ipairs(BALLS_FOLDER:GetChildren()) do
				if ball:IsA("BasePart") then
					table.insert(data.BallsData, {
						CFrame = ball.CFrame,
						Velocity = ball.AssemblyLinearVelocity
					})
				end
			end

			for _, p in ipairs(Players:GetPlayers()) do
				if p.Team then
					data.PlayerTeams[tostring(p.UserId)] = p.Team.Name
				end
				if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
					data.PlayerPositions[tostring(p.UserId)] = p.Character.HumanoidRootPart.CFrame
				end
			end

			local playersToTeleport = Players:GetPlayers()
			if #playersToTeleport > 0 then
				local options = Instance.new("TeleportOptions")
				options:SetTeleportData(data)
				TeleportService:TeleportAsync(game.PlaceId, playersToTeleport, options)
			end
		end,
	},
	{
		{ "givecoins", "addcoins" },
		{ "Dá coins para um jogador.", ";givecoins nick quantidade" },
		5,
		{ "player", "number" },
		function(pl, args)
			local Players = game:GetService("Players")
			local ServerScriptService = game:GetService("ServerScriptService")
			local PlayerModule = require(ServerScriptService.Modules.Systems.Player)
			
			local targetPlayers = args[1]
			local amount = args[2]
			
			if not targetPlayers or #targetPlayers == 0 then
				return "Jogador não encontrado."
			end
			
			if not amount or amount == 0 then
				return "Quantidade inválida."
			end
			
			for _, targetPlayer in ipairs(targetPlayers) do
				PlayerModule:AddCoins(targetPlayer, amount)
				print("[Admin] " .. pl.Name .. " deu " .. amount .. " coins para " .. targetPlayer.Name)
			end
		end,
	},
	{
		{ "resetcoins", "setcoins" },
		{ "Define a quantidade exata de coins de um jogador.", ";resetcoins nick quantidade" },
		5,
		{ "player", "number" },
		function(pl, args)
			local Players = game:GetService("Players")
			local ServerScriptService = game:GetService("ServerScriptService")
			local PlayerModule = require(ServerScriptService.Modules.Systems.Player)
			
			local targetPlayers = args[1]
			local amount = args[2]
			
			if not targetPlayers or #targetPlayers == 0 then
				return "Jogador não encontrado."
			end
			
			if amount == nil then
				return "Quantidade inválida."
			end
			
			for _, targetPlayer in ipairs(targetPlayers) do
				local leaderstats = targetPlayer:FindFirstChild("leaderstats")
				if leaderstats and leaderstats:FindFirstChild("Coins") then
					local currentCoins = leaderstats.Coins.Value
					local difference = amount - currentCoins
					PlayerModule:AddCoins(targetPlayer, difference)
					print("[Admin] " .. pl.Name .. " setou coins de " .. targetPlayer.Name .. " para " .. amount)
				end
			end
		end,
	},
	-- {
	-- 	{ "test", "othertest" },
	-- 	{ "Test command.", "Example" },
	-- 	6,
	-- 	{ "number", "string/" },
	-- 	function(pl, args)
	-- 		print(pl, args[1], args[2])
	-- 	end,
	-- },
}

