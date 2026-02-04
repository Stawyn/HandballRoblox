local Players = game:GetService("Players")

local SET_PIECES_FOLDER = workspace:WaitForChild("Core"):WaitForChild("SetPieces")
local BallService = require(game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("BallService"))

local SET_PIECES = {
	["AGK"] = Vector3.new(0, 2.5, -298.816),
	["HGK"] = Vector3.new(0, 2.5, 298.816),
	["APK"] = Vector3.new(0, 2.5, -251.126),
	["HPK"] = Vector3.new(0, 2.5, 251.126),
	["KO"] = Vector3.new(0, 2.5, 0),
	["ALCK"] = Vector3.new(-198, 2.5, -313.004),
	["HLCK"] = Vector3.new(-198, 2.5, 313.004),
	["ARCK"] = Vector3.new(198, 2.5, -313.004),
	["HRCK"] = Vector3.new(198, 2.5, 313.004),
}

function OnPlayerAdded(player: Player)
	player.Chatted:Connect(function(message: string)
		if player.Team.Name ~= "Officials" then return end
		if string.sub(message, 1, 1) ~= ":" then return end
		local setPieceName = message:gsub(":", "")
		setPieceName = string.upper(setPieceName)
		local foundSetPiece = SET_PIECES[setPieceName]
		if foundSetPiece ~= nil then
			BallService.new(foundSetPiece)
		end
	end)
end

Players.PlayerAdded:Connect(OnPlayerAdded)
for i, v in ipairs(Players:GetPlayers()) do
	task.spawn(OnPlayerAdded, v)
end
