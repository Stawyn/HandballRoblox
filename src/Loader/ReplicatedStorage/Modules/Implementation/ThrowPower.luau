local Utils = require(game:GetService("ReplicatedStorage"):WaitForChild("Utilities"):WaitForChild("Utils"))
local ThrowHeight = {
	{
		limit = 20,
		multiplier = 1,
	},
	{
		limit = 35,
		multiplier = 0.8
	},
	{
		limit = 50, 
		multiplier = 0.75
	},
	{
		limit = 60,
		multiplier = 0.7
	},
	{
		limit = math.huge,
		multiplier = 0.6
	}
}

local CORE_FOLDER = workspace:WaitForChild("Core")
local THROW_BUFF = 1.5
local HOME_GLT = CORE_FOLDER:WaitForChild("GLT"):WaitForChild("Home")
local AWAY_GLT = HOME_GLT.Parent.Away
local RADIUS = 80


function dotMultiplier(t: number)
	if t > 0.9 then
		return 1
	end
	
	--[[
	The following line was determined by the following points:
	P0 = (-1, 0.375)
	P1 = (0.9, 1)
	--]]
	local a = 25/76
	local b = 107/152

	return a*t + b
end

function throwPowerTransformation(x: number)	
	local int = math.floor(x)
	int = math.max(0, int)

	local t = THROW_BUFF - 0.6 * math.log(int + 1)
	return math.max(0.5, t)
end

return function(mouseDirection: vector, mousePosition: vector, playerLookDirection: vector, power: number, playerPosition: vector, player: Player)
	local yAxis = math.abs(mouseDirection.y) * 100
	local finalPower = power

	for _, powerInfo in ThrowHeight do
		if yAxis <= powerInfo.limit then
			finalPower *= powerInfo.multiplier
			break
		end
	end
	
	local mouseDir = vector.normalize(mousePosition * vector.create(1, 0, 1))
	local front = vector.normalize(playerLookDirection * vector.create(1, 0, 1))
	
	local dot = math.clamp(vector.dot(mouseDir, front), -1, 1)
	
	-- Verifica se a bola está sendo mirada ao gol
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {HOME_GLT, AWAY_GLT}
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	local result = workspace:Raycast(playerPosition, vector.normalize(mouseDirection) * RADIUS, raycastParams)
	local multiplier = 1
	if result then
		local t = Utils:CountOpponentsInRadius(player, playerPosition)
		multiplier = throwPowerTransformation(t)
	end
	
	return finalPower * dotMultiplier(dot) * multiplier
end
