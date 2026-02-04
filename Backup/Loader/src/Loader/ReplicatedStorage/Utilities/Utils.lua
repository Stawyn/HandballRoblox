local Utils = {}
local Teams = game:GetService("Teams")

function Utils:MergeTables<T>(t1: { T }, t2: { T }): {T}
	local newTable = table.create(#t1 + #t2, nil)
	local currIndex = 1
	
	for i = 1, #t1 do
		newTable[currIndex] = t1[i]
		currIndex += 1
	end
	
	for i = 1, #t2 do
		newTable[currIndex] = t2[i]
		currIndex += 1
	end
	
	return newTable
end

function Utils:CountOpponentsInRadius(blacklistPlayer: Player, center: Vector3)
	local r = 14
	local radiusSquared = 10*10
	local count = 0

	local presumedTeam = blacklistPlayer.Team.Name :: string
	local opponents = {}
	if presumedTeam:find("Home") then
		opponents = Utils:MergeTables(Teams["Away Team"]:GetPlayers(), Teams["-Away Goalkeeper"]:GetPlayers())
	elseif presumedTeam:find("Away") then
		opponents = Utils:MergeTables(Teams["Home Team"]:GetPlayers(), Teams["-Home Goalkeeper"]:GetPlayers())
	else
		return -1
	end

	for _, player in opponents do
		if player == blacklistPlayer then
			continue
		end
		local character = player.Character
		if character then
			local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if humanoidRootPart then
				local offset = humanoidRootPart.Position - center
				local distanceSquared = offset:Dot(offset)

				if distanceSquared <= radiusSquared then
					count += 1
				end
			end
		end
	end

	return count
end

function Utils:IsPointInHomeArea(point: Vector3): boolean
	local centerX = -139.469
	local radius = 100
	local minX = -149.469

	local a, c = point.X, point.Z

	if a < minX then
		return false
	end

	local distX = a - centerX
	local distZ = c
	local distance = math.sqrt(distX * distX + distZ * distZ)

	return distance <= radius
end

function Utils:IsPointInAwayArea(point: Vector3): boolean
	local centerX = 139.469
	local radius = 100
	local maxX = 149.469

	local a, c = point.X, point.Z

	if a > maxX then
		return false
	end

	local distX = a - centerX
	local distZ = c
	local distance = math.sqrt(distX * distX + distZ * distZ)

	return distance <= radius
end


return Utils