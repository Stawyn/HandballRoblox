local Teams = game:GetService("Teams")
local SSS = game:GetService("ServerScriptService")

local TimerModule
if SSS:FindFirstChild("Modules") then
	if SSS.Modules:FindFirstChild("Implementation") then
		if SSS.Modules.Implementation:FindFirstChild("Timer") then
			TimerModule = require(SSS.Modules.Implementation.Timer)
		end
	end
end


return function(_K)
	_K.Registry.registerCommand(_K, {
		name = "addextratime",
		aliases = { "addet", "et" },
		description = "Adds extra time to the match, wich have a duration of 7 minutes per half. You must me the match referee to execute this command",

		group = "General",
		noLog = false, 
		args = {
			{
				type = "integer",
				name = "Extra time",
				description = "Ammout of extra time to add to the match",
				optional = false, 

				permissions = {},

	
				lowerRank = false,
				ignoreSelf = false,
				shouldRequest = false, 
			}
		},
		permissions = {}, 

		run = function(context, et: number)
			if not TimerModule then
				return
			end
			
			if context.fromPlayer.Team.Name ~= "Officials" then
				return
			end
			
			TimerModule:AddTime(et)
		end,
	})
end