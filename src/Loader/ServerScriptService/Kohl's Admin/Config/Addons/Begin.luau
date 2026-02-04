local Teams = game:GetService("Teams")
local SSS = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorkSpace = game:GetService("Workspace")

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
		name = "begin",
		aliases = { },
		description = "Begin the match half. You must me the match referee to execute this command",

		group = "General",
		noLog = false, 
		args = {},
		permissions = {}, 

		run = function(context, player: Player)
			if not ABHLeague then
				return
			end
			if context.fromPlayer.Team.Name ~= "Officials" then
				return
			end
			ABHLeague:BeginLeague()
		end,
	})
end
