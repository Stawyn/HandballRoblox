type PositionProperties = {
	GK: Player?,
	LB: Player?,
	CB: Player?,
	RB: Player?,
	LCM: Player?,
	RCM: Player?,
	ST: Player?,
	LW: Player?,
	RW: Player?
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Teams = game:GetService("Teams")
local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")

local RefereeService = require(ServerScriptService:WaitForChild("Services"):WaitForChild("RefereeService"))
local TimerModule = require(ServerScriptService:WaitForChild("Services"):WaitForChild("RefereeService"):WaitForChild("TimerModule"))
local ShuffleTable = require(script:WaitForChild("ShuffleTable"))
local GetKickOffPart = require(ServerScriptService:WaitForChild("Auto"):WaitForChild("Services"):WaitForChild("KickOffPart"))
local SetPieceHandler = require(script:WaitForChild("SetPieceHandler"))
local OrganizeTable = require(script:WaitForChild("OrganizeTable"))
local BallService = require(ServerScriptService:WaitForChild("Services"):WaitForChild("BallService"))
local Maid = require(ReplicatedStorage:WaitForChild("Utils"):WaitForChild("Maid"))
local RunService = game:GetService("RunService")

local SetPieceRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SetPiece")
local GameConfigFolder = ReplicatedStorage:WaitForChild("Config")

local AutoService = {}

local lastAttackMaid = Maid.new()

local BALLS_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Balls")
local GAMEINFO_FOLDER = ReplicatedStorage:WaitForChild("GameInfo")
local STATS_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Stats")
local DEFAULT_INTERMISSION_SECONDS = GameConfigFolder.INTERMISSION.Value -- 30
local DEFAULT_POSITION_SELECT_SECONDS = GameConfigFolder.POSITION_SELECT_INTERMISSION.Value -- 30
local MINIMUM_PLAYERS = GameConfigFolder.MINIMUM_PLAYERS.Value -- 2
local POSITIONS_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Positions")
local SETPIECE_PART = ServerStorage:WaitForChild("GameSourceServer"):WaitForChild("SetPiece")
local GOALKICK_PART = ServerStorage:WaitForChild("GameSourceServer"):WaitForChild("GoalKick")
local GOALKICK_ZAXIS = 266.5

local seconds = DEFAULT_INTERMISSION_SECONDS
local initialized = GAMEINFO_FOLDER.Initialized
local intermissionCooldown = false
local countingDown = false

local selectSeconds = DEFAULT_POSITION_SELECT_SECONDS

local assignedkickOff = {
	Player = nil,
	Team = nil
}
local assignedSetPiece: {["BasePart"]: BasePart, ["Player"]: Player, ["Team"]: "Home" | "Away"} = {
	BasePart = nil,
	Player = nil,
	Team = nil
}

local positions = {
	["GK"] = true,
	["LB"] = true,
	["CB"] = true, 
	["RB"] = true ,
	["LCM"] = true,
	["RCM"] = true ,
	["ST"] = true,
	["LW"] = true,
	["RW"] = true,
}


local homePositions = {positions = {}} :: {positions: PositionProperties}
local awayPositions = {positions = {} } :: {positions: PositionProperties}

function ResetGame()
	RefereeService:ResetTimer()
	RefereeService:ResetScores()
	initialized.Value = false
	intermissionCooldown = false

	table.clear(assignedSetPiece)
	table.clear(assignedkickOff)
	table.clear(homePositions.positions)
	table.clear(awayPositions.positions)

	task.wait(5)

	if #Players:GetPlayers() >= MINIMUM_PLAYERS then
		AutoService:StartIntermission()
	else
		GAMEINFO_FOLDER.Message.Value = "The game must have at least 2 players to start"
	end
end

function UpdatePartsPosition(): number
	local totalPlayers = 0

	for _, positionPart: BasePart in pairs(POSITIONS_FOLDER:GetDescendants()) do
		if positionPart.Parent.Name == "Home" then
			if homePositions.positions[positionPart.Name] then
				positionPart.BrickColor = BrickColor.new("Really blue")
				positionPart.Owner.TextLabel.Text = homePositions.positions[positionPart.Name].Name
				totalPlayers += 1
			else
				positionPart.BrickColor = BrickColor.new("Bright blue")
				positionPart.Owner.TextLabel.Text = positionPart.Name
			end
		elseif positionPart.Parent.Name == "Away" then
			if awayPositions.positions[positionPart.Name] then 
				positionPart.BrickColor = BrickColor.new("Really red")
				positionPart.Owner.TextLabel.Text = awayPositions.positions[positionPart.Name].Name
				totalPlayers += 1	
			else
				positionPart.BrickColor = BrickColor.new("Terra Cotta")
				positionPart.Owner.TextLabel.Text = positionPart.Name
			end	
		end
	end

	return totalPlayers
end

function ChangePositionsState(state: boolean)
	for _, part: BasePart in pairs(POSITIONS_FOLDER:GetDescendants()) do
		if not part:IsA("BasePart") then continue end
		part.CanTouch = state
		part.Transparency = state and 0 or 1
		if state then
			if part.Parent.Name == "Home" then
				part.BrickColor = BrickColor.new("Bright blue")
			else
				part.BrickColor = BrickColor.new("Terra Cotta")
			end
			part.Owner.Enabled = true
			part.Owner.TextLabel.Text = part.Name
		else
			part.Owner.Enabled = false
		end
	end
end

function GetPlayerHomePositionPart(player: Player): BasePart?
	local foundPosition = nil
	for index: string, plr: Player in pairs(homePositions.positions) do
		if plr == player then
			foundPosition = index
		end
	end

	if not foundPosition then
		return
	end

	return POSITIONS_FOLDER.Home[foundPosition]
end

function GetPlayerAwayPositionPart(player: Player): BasePart?
	local foundPosition = nil
	for index: string, plr: Player in pairs(awayPositions.positions) do
		if plr == player then
			foundPosition = index
		end
	end

	if not foundPosition then
		return
	end

	return POSITIONS_FOLDER.Away[foundPosition]
end


function GetClosestPlayerTOGK(team: Team): Player?
	local glt = workspace:WaitForChild("Core"):WaitForChild("GoalDetections")[team.Name]

	local closestPlayer = nil
	local closestMagnitude = math.huge
	for _, player: Player in pairs(team:GetPlayers()) do
		local character = player.Character
		if character and character:FindFirstChild("HumanoidRootPart") then
			local magnitude = (character.HumanoidRootPart.Position - glt.Position).Magnitude
			if magnitude < closestMagnitude then
				closestMagnitude = magnitude
				closestPlayer = player
			end
		end
	end

	return closestPlayer
end

function GetRandomPosition(isHome: boolean): string
	local positionsTable = positions

	if isHome then
		for position: string,_ in pairs(homePositions.positions) do
			positionsTable[position] = nil
		end
	else
		for position: string,_ in pairs(awayPositions.positions) do
			positionsTable[position] = nil
		end
	end

	local foundPosition = nil

	for index, value in pairs(positionsTable) do
		foundPosition = index
	end

	return foundPosition
end

function PosititionPlayersToPosition()
	for _, player in pairs(Players:GetPlayers()) do
		if not player.Character and not player.Character:FindFirstChild("HumanoidRootPart") then continue end
		local teamName = player.Team.Name
		if teamName:find("Home") then
			local partPosition = GetPlayerHomePositionPart(player)
			if not partPosition then
				local randomizedPosition = GetRandomPosition(true)
				homePositions.positions[randomizedPosition] = player
				partPosition = GetPlayerHomePositionPart(player)
			end
			player.Character.HumanoidRootPart.CFrame = CFrame.new(partPosition.Position + Vector3.new(0, 10, 0))
		elseif teamName:find("Away") then
			local partPosition = GetPlayerAwayPositionPart(player)
			if not partPosition then
				local randomizedPosition = GetRandomPosition(false)
				awayPositions.positions[randomizedPosition] = player
				partPosition = GetPlayerAwayPositionPart(player)
			end
			player.Character.HumanoidRootPart.CFrame = CFrame.new(partPosition.Position + Vector3.new(0, 10, 0))
		end
	end
end

function GetClosestPlayersFromPosition(position: Vector3, players: {Players})
	local closetMagnitude = math.huge
	local closestPlayer
	
	for _, player: Player in pairs(players) do
		if not player.Character and not player.Character:FindFirstChild("HumanoidRootPart") then continue end
		local magnitude = (player.Character.HumanoidRootPart.Position - position).Magnitude
		if magnitude < closetMagnitude then
			closetMagnitude = magnitude
			closestPlayer = player
		end
	end
	
	
	return closestPlayer
end

function HandlePlayerTaking(player: Player, position: Vector3, teamThatsTaking: "Home" | "Away")
	local playerThatsTaking = player
	local presumedTeam = teamThatsTaking == "Home" and Teams["Home"] or Teams["Away"]
	
	if not playerThatsTaking then
		local goalkeeper = Teams["-"..teamThatsTaking.." Goalkeeper"]:GetPlayers()[1]
		local players = presumedTeam:GetPlayers()
		local closestPlayer = GetClosestPlayersFromPosition(position, players)
		
		if closestPlayer then
			playerThatsTaking = closestPlayer
		elseif not closestPlayer and goalkeeper then
			playerThatsTaking = goalkeeper
		end
	end
	
	if playerThatsTaking and playerThatsTaking.Character and playerThatsTaking.Character:FindFirstChild("HumanoidRootPart") then
		playerThatsTaking:SetAttribute("SetPiece", true)
		playerThatsTaking.Character.HumanoidRootPart.AssemblyLinearVelocity = Vector3.new()
		playerThatsTaking.Character.HumanoidRootPart.CFrame = CFrame.new(position)
		task.delay(6, function()
			playerThatsTaking:SetAttribute("SetPiece", false)
		end)
	end
end


function HandleKickOff(startingTeam: "Home" | "Away")
	if TimerModule:GetLA() then
		FinishGame()
		return
	end
	assignedkickOff.Team = startingTeam

	PosititionPlayersToPosition()
	GetKickOffPart()

	task.delay(6, function()
		local playerThatsTaking = assignedkickOff.Player
		local position = Vector3.new(0, 8, 0)
		
		HandlePlayerTaking(playerThatsTaking, position, startingTeam)

		local ballInstance = BallService.new(position, startingTeam)
		table.clear(assignedkickOff)
		
		GAMEINFO_FOLDER.Taker.Value = ""
		GAMEINFO_FOLDER.Message.Value = "Match in progress"
		TimerModule:Resume()
	end)

	for _, player in pairs(Players:GetPlayers()) do
		local teamName = player.Team.Name
		if teamName:find("Home") or teamName:find("Away") then
			SetPieceRemote:FireClient(player, "Kick Off", startingTeam == "Home")
		end
	end
end


function HandleMatchStarting()
	if initialized.Value then return end
	initialized.Value = true
	GAMEINFO_FOLDER.Message.Value = "Match in Progress"

	RandomizePlayersTeams()
	ChangePositionsState(true)

	selectSeconds = DEFAULT_POSITION_SELECT_SECONDS
	GAMEINFO_FOLDER.Message.Value = "Select your position - "..tostring(selectSeconds).." remaining"
	while selectSeconds > 0 do
		task.wait(1)
		selectSeconds -= 1
		GAMEINFO_FOLDER.Message.Value = "Select your position - "..tostring(selectSeconds).." remaining"
	end

	ChangePositionsState(false)
	HandleKickOff("Home")
end

function FinishGame()
	if not initialized.Value then return end
	lastAttackMaid:Destroy()
	workspace.Core.Balls:ClearAllChildren()
	initialized.Value = false
	GAMEINFO_FOLDER.Message.Value = "Full Time"

	local scoresFolder = STATS_FOLDER.Scores
	print("FULL TIME - "..tostring(scoresFolder.Home.Value).." - "..tostring(scoresFolder.Away.Value))
	local winnerMessage = if scoresFolder.Home.Value > scoresFolder.Away.Value then 
		"FT - Home team won!" 
		elseif scoresFolder.Away.Value > scoresFolder.Home.Value then
		"FT - Away team won!" 
		elseif scoresFolder.Away.Value == scoresFolder.Home.Value then
		"FT - It's a draw!"
		else
		"FT"

	for _, player in pairs(Players:GetPlayers()) do
		SetPieceRemote:FireClient(player, winnerMessage, nil)
	end

	for _, player in pairs(Players:GetPlayers()) do
		player.TeamColor = BrickColor.new("Smoky grey")
	end

	ChangePositionsState(false)
	ResetGame()
end

function RandomizePlayersTeams()
	local players = game:GetService("Players"):GetPlayers()
	ShuffleTable(players)

	for index, player in pairs(players) do
		local lowestTeamPlayers = GetLowestTeamQuantity()
		
		if lowestTeamPlayers == "Home" then
			player.TeamColor = BrickColor.new("Really blue")
		elseif lowestTeamPlayers == "Away" then
			player.TeamColor = BrickColor.new("Really red")
		else
			local random = math.random(1, 2)
			if random == 1 then
				player.TeamColor = BrickColor.new("Really blue")
			else
				player.TeamColor = BrickColor.new("Really red")
			end
		end
	end
end

function RemovePlayerFromPosition(player: Player)
	for index, position in pairs(homePositions.positions) do
		if position == player then
			homePositions.positions[index] = nil
			break 
		end
	end

	for index, position in pairs(awayPositions.positions) do
		if position == player then
			awayPositions.positions[index] = nil
			break 
		end
	end

	for index, part in pairs(POSITIONS_FOLDER:GetDescendants()) do
		if part:IsA("BasePart") and part.Owner.TextLabel.Text == player.Name then
			part.Owner.TextLabel.Text = part.Name
		end
	end
end

function GetLowestTeamQuantity(): "Home" | "Away" | "None"
	local home = #Teams.Home:GetPlayers() + #Teams["-Home Goalkeeper"]:GetPlayers()
	local away = #Teams.Away:GetPlayers() + #Teams["-Away Goalkeeper"]:GetPlayers()

	if home < away then
		return "Home"
	elseif away < home then
		return "Away"
	else
		return "None"
	end
end

function AutoService:HandleGoal(sideStarting: "Home" | "Away")
	TimerModule:Pause()
	task.wait(5)
	HandleKickOff(sideStarting)
end

function HandleBallOutOfBounds(ballInstance: BasePart)
	ballInstance.CanTouch = false
	ballInstance.Highlight.FillColor = Color3.new(255, 0, 0)
	ballInstance.Highlight.FillTransparency = 0
	Debris:AddItem(ballInstance, 3)
end

function AutoService:HandleLastAttack()
	local firstBall = workspace.Core:WaitForChild("Balls"):GetChildren()[1]

	if firstBall then
		local ballModel = BallService:GetBall(firstBall)
		if not ballModel then FinishGame() return end

		local playerOnBall = ballModel.Data.PlayerOnBall
		local lastPlayerOnBall = ballModel.Data.LastPlayerOnBall

		if playerOnBall.Value then
			local team = playerOnBall.Value.Team.Name:find("Home") and "Home" or "Away"
			TimerModule:SetLAText(team)
			lastAttackMaid:GiveTask(playerOnBall:GetPropertyChangedSignal("Value"):Connect(function()
				if playerOnBall.Value == nil then return end
				local oppositeTeam = not playerOnBall.Value.Team.Name:find(team)
				if oppositeTeam then
					FinishGame()
				end
			end))
		elseif not playerOnBall.Value and lastPlayerOnBall.Value then
			local team = lastPlayerOnBall.Value.Team.Name:find("Home") and "Home" or "Away"
			TimerModule:SetLAText(team)
			lastAttackMaid:GiveTask(playerOnBall:GetPropertyChangedSignal("Value"):Connect(function()
				if playerOnBall.Value == nil then return end
				local oppositeTeam = not playerOnBall.Value.Team.Name:find(team)
				if oppositeTeam then
					FinishGame()
				end
			end))
		else
			FinishGame()
		end
	else
		FinishGame()
	end
end

function AutoService:HandleOffside(isHomePosession: boolean, offsidePosition: number)
	TimerModule:Pause()
	local clone = SETPIECE_PART:Clone()
	clone.BrickColor = isHomePosession and BrickColor.new("Really blue") or BrickColor.new("Really red")
	clone.Position = Vector3.new(0, 0.5, offsidePosition)
	AutoService:AlertSetPiece(isHomePosession, clone, "Offside")
end

function AutoService:HandleFlickspam(playerOnBall: Player, ballPosition: Vector3, ballPart: BasePart)
	HandleBallOutOfBounds(ballPart)

	local ballInstance = BallService:GetBall(ballPart)
	if not ballInstance then return end
	ballInstance:RemoveWeld()

	local homePosession = not playerOnBall.Team.Name:find("Home")
	local clone = SETPIECE_PART:Clone()
	clone.BrickColor = homePosession and BrickColor.new("Really blue") or BrickColor.new("Really red")
	clone.Position = Vector3.new(ballPosition.X, 0.5, ballPosition.Z)

	AutoService:AlertSetPiece(homePosession, clone, "Flick spam")
end

function AutoService:StartIntermission()
	if initialized.Value == true then return end
	if intermissionCooldown then return end
	intermissionCooldown = true

	seconds = DEFAULT_INTERMISSION_SECONDS
	GAMEINFO_FOLDER.Intermission.Value = seconds
	GAMEINFO_FOLDER.Message.Value = "Intermission "..tostring(seconds)
	countingDown = true
	while seconds > 0 and countingDown do
		task.wait(1)
		seconds -= 1
		GAMEINFO_FOLDER.Intermission.Value = seconds
		GAMEINFO_FOLDER.Message.Value = "Intermission "..tostring(seconds)
	end

	if seconds > 0 then return end
	countingDown = false
	HandleMatchStarting()
end

function AutoService:StopIntermission()
	if initialized.Value == true then return end
	if not intermissionCooldown then return end
	intermissionCooldown = false

	seconds = DEFAULT_INTERMISSION_SECONDS
	countingDown = false
	GAMEINFO_FOLDER.Message.Value = "The game must have at least 2 players to start"
end

function AutoService:AlertSetPiece(homePosession: boolean, setPiecePart: BasePart, text: string, ballPosition: Vector3)
	if TimerModule:GetLA() then
		FinishGame()
		return
	end

	if assignedSetPiece.BasePart then return end

	task.delay(6, function()
		if not assignedSetPiece.BasePart then return end
		if assignedSetPiece.BasePart ~= setPiecePart then return end
		local part = SetPieceHandler(setPiecePart, ballPosition)
		local playerThatsTaking = assignedSetPiece.Player
		local teamTaking = part.BrickColor == BrickColor.new("Really blue") and "Home" or "Away"
		
		HandlePlayerTaking(playerThatsTaking, Vector3.new(part.Position.X, 8, part.Position.Z), teamTaking)
		table.clear(assignedSetPiece)
		
		GAMEINFO_FOLDER.Taker.Value = ""
	end)

	assignedSetPiece.BasePart = setPiecePart
	assignedSetPiece.Team = homePosession and "Home" or "Away"

	for _, player in pairs(Players:GetPlayers()) do
		local teamName = player.Team.Name
		if teamName:find("Home") or teamName:find("Away") then
			SetPieceRemote:FireClient(player, text, homePosession)
		end
	end
end

function AutoService:GetPlayerPosition(player: Player): Player?
	for _, position in pairs(homePositions.positions) do
		if position == player then
			return position
		end
	end

	for _, position in pairs(awayPositions.positions) do
		if position == player then
			return position
		end
	end

	return nil 
end

function AutoService:AssignGoalKick(homePosession: boolean)
	if TimerModule:GetLA() then
		FinishGame()
		return
	end
	
	local setPiecePart = GOALKICK_PART:Clone()
	setPiecePart.BrickColor = homePosession and BrickColor.new("Really blue") or BrickColor.new("Really red")
	setPiecePart.Position = homePosession and Vector3.new(0, 0.5, GOALKICK_ZAXIS) or Vector3.new(0, 0.5, -GOALKICK_ZAXIS)	
	
	for _, player in pairs(Players:GetPlayers()) do
		SetPieceRemote:FireClient(player, "Goal kick", nil)
	end

	task.wait(6)

	local team = homePosession and "Home" or "Away"
	local goalkeeper: Player? = Teams["-"..team.." Goalkeeper"]:GetPlayers()[1]
	local part = SetPieceHandler(setPiecePart)

	if goalkeeper then
		if goalkeeper.Character and goalkeeper.Character:FindFirstChild("HumanoidRootPart") then
			goalkeeper.Character.HumanoidRootPart.CFrame = CFrame.new(part.Position.X, 8, part.Position.Z)
		end
	else
		local closestPlayer = GetClosestPlayerTOGK(Teams[team])
		if closestPlayer then
			closestPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(part.Position.X, 8, part.Position.Z)
		end
	end
end

function AutoService:AssignSetPiece(player: Player)
	local assignedPiece
	local isKickOff = assignedkickOff.Team and not assignedkickOff.Player
	local isSetPiece = assignedSetPiece.BasePart and not assignedSetPiece.Player
	local teamName = player.Team.Name

	if isSetPiece and teamName:find(assignedSetPiece.Team) then
		assignedPiece = assignedSetPiece
	elseif isKickOff and teamName:find(assignedkickOff.Team) then
		assignedPiece = assignedkickOff
	end

	if assignedPiece then
		assignedPiece.Player = player
		GAMEINFO_FOLDER.Taker.Value = player.Name
	end
end

function AutoService:AssignPlayerToPosition(player: Player, desiredPosition: string)
	if not positions[desiredPosition] then return end

	local currentPlayerTeam = player.Team.Name

	if currentPlayerTeam:find("Home") then
		local existingPlayer: Player? = homePositions.positions[desiredPosition]
		if existingPlayer then return end
		RemovePlayerFromPosition(player)
		homePositions.positions[desiredPosition] = player
	elseif currentPlayerTeam:find("Away") then
		local existingPlayer: Player? = awayPositions.positions[desiredPosition]
		if existingPlayer then return end
		RemovePlayerFromPosition(player)
		awayPositions.positions[desiredPosition] = player
	end

	if desiredPosition == "GK" then
		if homePositions.positions["GK"] == player then
			player.TeamColor = BrickColor.new("Navy blue")
		elseif awayPositions.positions["GK"] == player then
			player.TeamColor = BrickColor.new("Maroon")
		end
	elseif desiredPosition ~= "GK" then
		if player.TeamColor == BrickColor.new("Navy blue") then
			player.TeamColor = BrickColor.new("Really blue")
		elseif player.TeamColor == BrickColor.new("Maroon") then
			player.TeamColor = BrickColor.new("Really red")
		end
	end

	local players = UpdatePartsPosition()
	if players >= #Players:GetPlayers() then
		selectSeconds = 5
	end
end

function AutoService:AssignPlayerToGK(player: Player)
	if not initialized.Value then return end
	if not GAMEINFO_FOLDER.Message.Value:find("progress") then return end	
	AutoService:AssignPlayerToPosition(player, "GK")
end

Players.PlayerRemoving:Connect(function(player)
	RemovePlayerFromPosition(player)
	UpdatePartsPosition()
end)

function AssignPlayerJoinedPosition(player: Player)
	if not GAMEINFO_FOLDER.Message.Value:find("progress") then return end
	
	local playingForHome = player.Team.Name:find("Home")
	local randomizedPosition = GetRandomPosition(playingForHome)
	
	if playingForHome then
		homePositions.positions[randomizedPosition] = player
	else
		awayPositions.positions[randomizedPosition] = player
	end
	
	if randomizedPosition == "GK" then
		player.TeamColor = playingForHome and BrickColor.new("Navy blue") or BrickColor.new("Maroon")
	else
		player.TeamColor = playingForHome and BrickColor.new("Really blue") or BrickColor.new("Really red")
	end
	UpdatePartsPosition()
end

Players.PlayerAdded:Connect(function(player)
	if not initialized.Value then return end

	local lowestTeam = GetLowestTeamQuantity()
	if lowestTeam == "Home" then
		player.TeamColor = BrickColor.new("Really blue")
		AssignPlayerJoinedPosition(player)
	elseif lowestTeam == "Away" then
		player.TeamColor = BrickColor.new("Really red")
		AssignPlayerJoinedPosition(player)
	else
		local randomize = math.random(1, 2)
		player.TeamColor = randomize == 1 and BrickColor.new("Really blue") or BrickColor.new("Really red")
		if player.Team.Name:find("Home") then
			AssignPlayerJoinedPosition(player)
		elseif player.Team.Name:find("Away") then
			AssignPlayerJoinedPosition(player)
		end
	end
end)

ChangePositionsState(false)

BALLS_FOLDER.ChildRemoved:Connect(function(ball)
	local highlightColor = ball.Highlight.FillColor
	if highlightColor == Color3.new(255, 0, 0) then return end
	if TimerModule:GetLA() then
		FinishGame()
		return
	end
	TimerModule:Pause()
	
	local seconds = 5
	GAMEINFO_FOLDER.Message.Value = "Match paused. Spawning a new ball in "..tostring(seconds)
	while seconds > 0 do
		task.wait(1)
		seconds -= 1
		GAMEINFO_FOLDER.Message.Value = "Match paused. Spawning a new ball in "..tostring(seconds)
	end
	
	local newBall = BallService.new(Vector3.new(0, 4, 0))
	TimerModule:Resume()
	GAMEINFO_FOLDER.Message.Value = "Match in progress"
end)

return AutoService

