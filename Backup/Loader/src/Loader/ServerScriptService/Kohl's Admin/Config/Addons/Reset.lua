local Teams = game:GetService("Teams")
local SSS = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REFEREE_EVENT = ReplicatedStorage:WaitForChild("Network"):WaitForChild("Referee")

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
		name = "reset",
		aliases = { },
		description = "Reset the match state",

		group = "General",
		noLog = false, 
		args = {},
		permissions = {

		}, 

		run = function(context, player: Player)
			if context.fromPlayer.Team.Name ~= "Officials" then
				return
			end

			REFEREE_EVENT:FireClient(context.fromPlayer, {
				action = "SHOW_CONFIRM_RESET"
			})
		end,
	})
end
