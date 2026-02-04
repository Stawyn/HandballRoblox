local Teams = game:GetService("Teams")
local SSS = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorkSpace = game:GetService("Workspace")

-- Espera o Loader terminar de mover todos os arquivos
ReplicatedStorage:WaitForChild("LoaderReady")

local cardSystem = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Systems"):WaitForChild("CardSystem"))
local ABHLeague = nil
local modulesFolder = SSS:WaitForChild("Modules", 10)
if modulesFolder then
	local implementationFolder = modulesFolder:WaitForChild("Implementation", 5)
	if implementationFolder then
		local abhLeagueModule = implementationFolder:FindFirstChild("ABHLeague")
		if abhLeagueModule then
			ABHLeague = require(abhLeagueModule)
		end
	end
end


return function(_K)
	_K.Registry.registerCommand(_K, {
		name = "fulltime",
		aliases = { "ft" },
		description = "Ends a match. You must be the match referee to execute this command",

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

			ABHLeague:FullTime()
			cardSystem:ResetAll()
		end,
	})
end
