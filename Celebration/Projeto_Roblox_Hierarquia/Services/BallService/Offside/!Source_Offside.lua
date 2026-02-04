type BallObject = {
	Instance: BasePart,
	CanTouch: boolean,
	Data: {
		["LastShoot"]: ObjectValue,
		["PlayerOnBall"]: ObjectValue,
		["LastShootShoot"]: ObjectValue,
		["LastPlayerOnBall"]: ObjectValue
	}
}

local Teams = game:GetService("Teams")
local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local matchStats: Folder = workspace:WaitForChild("Core"):WaitForChild("Stats")
local matchValue: StringValue = matchStats:WaitForChild("Match")
local swapped: BoolValue = matchStats:WaitForChild("Switched")
local attackerBrick: BasePart = ServerStorage:WaitForChild("Offside"):WaitForChild("AttackerPosition")
local defenderBrick: BasePart = ServerStorage:WaitForChild("Offside"):WaitForChild("DefenderPosition")

local gameEvents = ReplicatedStorage:WaitForChild("Bindable"):WaitForChild("GameEvents")

local MINIMUM_OFFSIDE_DISTANCE: number = 1
local BOX_POSITION: number = 207.5

function GetLastPlayerPosition(positions: {[Player]: number}, isPositive: boolean): number
	if isPositive then
		local highestPosition: number = -math.huge
		
		for player: Player, position: number in pairs(positions) do
			if position < highestPosition then continue end
			highestPosition = position
		end
		
		return highestPosition > 0 and highestPosition or 0
	else
		local lowestPosition: number = math.huge
		
		for player: Player, position: number in pairs(positions) do
			if position > lowestPosition then continue end
			lowestPosition = position
		end

		return lowestPosition < 0 and lowestPosition or 0
	end
end

function GetPositionToCompare(firstPosition: number, secondPosition: number, isMore: boolean): number
	if isMore then
		return firstPosition > secondPosition and firstPosition or secondPosition
	else
		return firstPosition < secondPosition and firstPosition or secondPosition
	end
end

function GenerateOffsidesLines(attackerPosition: number, defenderPosition: number)
	local attBrick = attackerBrick:Clone()
	local defBrick = defenderBrick:Clone()

	attBrick.Position = Vector3.new(attackerPosition, .5, 0)
	defBrick.Position = Vector3.new(defenderPosition, .5, 0)

	attBrick.Parent = workspace
	defBrick.Parent = workspace

	Debris:AddItem(attBrick, 5)
	Debris:AddItem(defBrick, 5)
end

function GetValueByItsIndex(givenTable, value)
	for i, v in pairs(givenTable) do
		if i ~= value then continue end
		return v
	end
	
	return nil
end

function HandleOffsideAutomatic(homePosession: boolean, position: number)
	gameEvents:Fire("Offside", homePosession, position)
end

type OffsideProperties = {
	currentPlayerPosition: number,
	resetCallback: () -> void,
	oppositeTeam: string,
	oppositeTeamPositions: {[Player]: number},
	currentBallPosition: number,
	checkByHighest: boolean
}

function CheckForOffside(offsideProperties: OffsideProperties)
	local oppositeGoalkeeper: Player = Teams["-"..offsideProperties.oppositeTeam.." Goalkeeper"]:GetPlayers()[1]
	
	if offsideProperties.checkByHighest then
		if offsideProperties.currentPlayerPosition < 1 then offsideProperties.resetCallback() return end
		local highestPosition: number = GetLastPlayerPosition(offsideProperties.oppositeTeamPositions, true)

		if not oppositeGoalkeeper or oppositeGoalkeeper and oppositeGoalkeeper.Character.HumanoidRootPart.Position.X > BOX_POSITION then
			if offsideProperties.currentPlayerPosition > highestPosition and offsideProperties.currentPlayerPosition > offsideProperties.currentBallPosition then
				task.spawn(HandleOffsideAutomatic, offsideProperties.oppositeTeam == "Home", offsideProperties.currentPlayerPosition)
				GenerateOffsidesLines(offsideProperties.currentPlayerPosition, highestPosition)
			end
		elseif oppositeGoalkeeper.Character.HumanoidRootPart.Position.X < BOX_POSITION then
			local goalkeeperPosition: number = oppositeGoalkeeper.Character.HumanoidRootPart.Position.X
			if offsideProperties.currentPlayerPosition > goalkeeperPosition and offsideProperties.currentPlayerPosition > highestPosition and offsideProperties.currentPlayerPosition > offsideProperties.currentBallPosition then
				local lastPosition: number = GetPositionToCompare(highestPosition, goalkeeperPosition, true)
				task.spawn(HandleOffsideAutomatic, offsideProperties.oppositeTeam == "Home", offsideProperties.currentPlayerPosition)
				GenerateOffsidesLines(offsideProperties.currentPlayerPosition, lastPosition)
			end
		end
	else
		if offsideProperties.currentPlayerPosition > 1 then offsideProperties.resetCallback() return end
		local lowestPosition: number = GetLastPlayerPosition(offsideProperties.oppositeTeamPositions, false)	
		
		if not oppositeGoalkeeper or oppositeGoalkeeper and oppositeGoalkeeper.Character.HumanoidRootPart.Position.X < -BOX_POSITION then
			if offsideProperties.currentPlayerPosition < lowestPosition and offsideProperties.currentPlayerPosition < offsideProperties.currentBallPosition then
				task.spawn(HandleOffsideAutomatic, offsideProperties.oppositeTeam == "Home", offsideProperties.currentPlayerPosition)
				GenerateOffsidesLines(offsideProperties.currentPlayerPosition, lowestPosition)
			end
		elseif oppositeGoalkeeper.Character.HumanoidRootPart.Position.X > -BOX_POSITION then
			local goalkeeperPosition: number = oppositeGoalkeeper.Character.HumanoidRootPart.Position.X
			if offsideProperties.currentPlayerPosition < goalkeeperPosition and offsideProperties.currentPlayerPosition < lowestPosition and offsideProperties.currentPlayerPosition < offsideProperties.currentBallPosition then
				local lastPosition: number = GetPositionToCompare(lowestPosition, goalkeeperPosition, false)
				task.spawn(HandleOffsideAutomatic, offsideProperties.oppositeTeam == "Home", offsideProperties.currentPlayerPosition)
				GenerateOffsidesLines(offsideProperties.currentPlayerPosition, lastPosition)
			end
		end
	end
end

return function (ballObject: BallObject)
	local playerOnBall = ballObject.Data.PlayerOnBall
	local lastShoot = ballObject.Data.LastShoot
	
	local homePositions: {[Player]: number} = {}
	local awayPositions: {[Player]: number} = {}
	local ballPosition: number = ballObject.Instance.Position.X
	
	local function reset()
		table.clear(homePositions)
		table.clear(awayPositions)
		ballPosition = ballObject.Instance.Position.X
	end
	
	-- Stores Position
	lastShoot:GetPropertyChangedSignal("Value"):Connect(function()
		reset()
		if not lastShoot.Value then return end
		for _, player: Player in pairs(Teams.Home:GetPlayers()) do
			if not player.Character then continue end
			if not player.Character.HumanoidRootPart then continue end
			homePositions[player] = player.Character.HumanoidRootPart.Position.X
		end
		
		for _, player: Player in pairs(Teams.Away:GetPlayers()) do
			if not player.Character then continue end
			if not player.Character.HumanoidRootPart then continue end
			awayPositions[player] = player.Character.HumanoidRootPart.Position.X
		end
		
		ballPosition = ballObject.Instance.Position.X
	end)
	
	-- Compares Position
	playerOnBall:GetPropertyChangedSignal("Value"):Connect(function()
		local currentPlayerOnBall: Player | nil = playerOnBall.Value
		local currentLastShoot: Player | nil = lastShoot.Value
		
		if matchValue.Value == "Training" then reset() return end
		if currentPlayerOnBall == nil or currentLastShoot == nil then reset() return end
		if currentPlayerOnBall == currentLastShoot then reset() return end
		if (#Teams.Home:GetPlayers() + #Teams["-Home Goalkeeper"]:GetPlayers()) < 1 or (#Teams.Away:GetPlayers() + #Teams["-Away Goalkeeper"]:GetPlayers()) < 1 then reset() return end
		if (currentPlayerOnBall.Team.Name == "Home" or currentPlayerOnBall.Team.Name == "-Home Goalkeeper") then
			if (currentLastShoot.Team.Name ~= "Home" and currentLastShoot.Team.Name ~= "-Home Goalkeeper") then reset() return end
		end
		if (currentPlayerOnBall.Team.Name == "Away" or currentPlayerOnBall.Team.Name == "-Away Goalkeeper") then
			if (currentLastShoot.Team.Name ~= "Away" and currentLastShoot.Team.Name ~= "-Away Goalkeeper") then reset() return end
		end
		
		local currentPlayerPosition: number = GetValueByItsIndex(homePositions, currentPlayerOnBall) or GetValueByItsIndex(awayPositions, currentPlayerOnBall)
		--local currentLastShootPosition: number = GetValueByItsIndex(homePositions, currentLastShoot) or GetValueByItsIndex(awayPositions, currentLastShoot)
		
		if not currentPlayerPosition then return end
		--if not currentPlayerOnBall or not currentLastShoot then return end
		print("passed")
		
		if not swapped.Value then
			if currentPlayerOnBall.Team.Name:find("Home") and not currentPlayerOnBall.Team.Name:find("@") then
				CheckForOffside({
					currentPlayerPosition = currentPlayerPosition,
					resetCallback = reset,
					oppositeTeam = "Away",
					oppositeTeamPositions = awayPositions,
					currentBallPosition = ballPosition,
					checkByHighest = false
				})
			elseif currentPlayerOnBall.Team.Name:find("Away") and not currentPlayerOnBall.Team.Name:find("@") then
				CheckForOffside({
					currentPlayerPosition = currentPlayerPosition,
					resetCallback = reset,
					oppositeTeam = "Home",
					oppositeTeamPositions = homePositions,
					currentBallPosition = ballPosition,
					checkByHighest = true
				})
			end
		else
			if currentPlayerOnBall.Team.Name:find("Home") and not currentPlayerOnBall.Team.Name:find("@") then
				CheckForOffside({
					currentPlayerPosition = currentPlayerPosition,
					resetCallback = reset,
					oppositeTeam = "Away",
					oppositeTeamPositions = awayPositions,
					currentBallPosition = ballPosition,
					checkByHighest = true
				})
			elseif currentPlayerOnBall.Team.Name:find("Away") and not currentPlayerOnBall.Team.Name:find("@") then
				CheckForOffside({
					currentPlayerPosition = currentPlayerPosition,
					resetCallback = reset,
					oppositeTeam = "Home",
					oppositeTeamPositions = homePositions,
					currentBallPosition = ballPosition,
					checkByHighest = false
				})
			end
		end
		
		reset()
	end)
end
