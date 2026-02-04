local AutoService = require(game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("AutoService"))
local SetPieceHandler = require(game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("AutoService"):WaitForChild("SetPieceHandler"))
local bindableGameEvents = game:GetService("ReplicatedStorage"):WaitForChild("Bindable"):WaitForChild("GameEvents")

bindableGameEvents.Event:Connect(function(argument: string, ...)
	if argument == "Offside" then
		local homePosession: boolean, position: number = ...
		AutoService:HandleOffside(homePosession, position)
	elseif argument == "Last Attack" then
		AutoService:HandleLastAttack()
	elseif argument == "Flick Spam" then
		local playerOnBall: Player, ballPosition: Vector3, ballPart = ...
		AutoService:HandleFlickspam(playerOnBall, ballPosition, ballPart)
	elseif argument == "Goalkeeper Possession" then
		local part: BasePart, existingBall: BasePart = ...
		SetPieceHandler(part, nil, existingBall)
	end
end)
