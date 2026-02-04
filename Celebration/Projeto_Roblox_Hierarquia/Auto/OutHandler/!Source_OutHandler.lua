local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BallService = require(ServerScriptService:WaitForChild("Services"):WaitForChild("BallService"))
local Maid = require(ReplicatedStorage:WaitForChild("Utils"):WaitForChild("Maid"))
local AutoService = require(ServerScriptService:WaitForChild("Services"):WaitForChild("AutoService"))

local SETPIECE_PART = ServerStorage:WaitForChild("GameSourceServer"):WaitForChild("SetPiece")
local GOALKICK_PART = ServerStorage:WaitForChild("GameSourceServer"):WaitForChild("GoalKick")
local OUT_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Outs")
local BALLS_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Balls")
local SETPIECES_FOLDER = workspace:WaitForChild("Core"):WaitForChild("SetPieces")
local KEEPER_MAX_BOUNDARY = 314.15
local GOALKICK_ZAXIS = 266.5
local CORNER_BASE_XAXIS = 196.25
local CORNER_BASE_ZAXIS = 311
local THROW_IN_BASE_XAXIS = 195

local outOfBoundsMaid = Maid.new()


function GetHomePosesion(playerOnBall: Player?, lastPlayerOnBall: Player?): boolean | nil
	if playerOnBall then
		if playerOnBall.Team.Name:find("Home") then
			-- Home last Posession
			return true
		else
			-- Away last Posession
			return false
		end
	elseif not playerOnBall and lastPlayerOnBall then
		if lastPlayerOnBall.Team.Name:find("Home") then
			-- Home last Posession
			return true
		else
			-- Away last Posession
			return false
		end
	end

	return nil -- Weird case where the ball is out but nobody owned?
end

function GoalKickSetPiece(isHomePosession: boolean)	
	AutoService:AssignGoalKick(isHomePosession)
end

function CornerKickSetPiece(isHomePosession: boolean, fromRight: boolean)
	local clone = SETPIECE_PART:Clone()
	clone.BrickColor = isHomePosession and BrickColor.new("Really blue") or BrickColor.new("Really red")
	clone.Position = if isHomePosession then
		Vector3.new(fromRight and CORNER_BASE_XAXIS or -CORNER_BASE_XAXIS, 0.5, -CORNER_BASE_ZAXIS)
		else
		Vector3.new(fromRight and CORNER_BASE_XAXIS or -CORNER_BASE_XAXIS, 0.5, CORNER_BASE_ZAXIS)
	
	AutoService:AlertSetPiece(isHomePosession, clone, "Corner kick")
end

function ThrowInSetPiece(isHomePosession: boolean, fromRight: boolean, zAxis: number)
	local clone = SETPIECE_PART:Clone()
	clone.BrickColor = isHomePosession and BrickColor.new("Really blue") or BrickColor.new("Really red")
	clone.Position = Vector3.new(fromRight and THROW_IN_BASE_XAXIS or -THROW_IN_BASE_XAXIS, 0.5, zAxis)
	AutoService:AlertSetPiece(isHomePosession, clone, "Throw in")
end

function HandleBallOutOfBounds(ballInstance: BasePart)
	ballInstance.CanTouch = false
	ballInstance.Highlight.FillColor = Color3.new(255, 0, 0)
	ballInstance.Highlight.FillTransparency = 0
	Debris:AddItem(ballInstance, 3)
end

function HandleTouchedPart(partThatTouched: BasePart)
	local touchedAxisZ = partThatTouched.Position.Z
	local touchedAxisX = partThatTouched.Position.X
	local ballModel = BallService:GetBall(partThatTouched)
	if not ballModel then return end

	local playerOnBall: Player? = ballModel.Data.PlayerOnBall.Value
	local lastPlayerOnBall: Player? = ballModel.Data.LastPlayerOnBall.Value

	local isHomePosession = GetHomePosesion(playerOnBall, lastPlayerOnBall)
	if isHomePosession == nil then return end
	
	-- Disable ball interaction
	ballModel:RemoveWeld()
	ballModel.Instance.CanTouch = false
	HandleBallOutOfBounds(ballModel.Instance)

	if touchedAxisZ >= KEEPER_MAX_BOUNDARY then
		-- Home area
		if isHomePosession then
			-- AWAY CK
			CornerKickSetPiece(false, touchedAxisX > 0)
		else
			-- HOME GK
			GoalKickSetPiece(true)
		end
	elseif touchedAxisZ <= -KEEPER_MAX_BOUNDARY then
		-- Away area
		if isHomePosession then
			-- AWAY GK
			GoalKickSetPiece(false)
		else
			-- HOME CK
			CornerKickSetPiece(true, touchedAxisX > 0)
		end
	else
		-- Throw in
		ThrowInSetPiece(not isHomePosession, touchedAxisX > 0, touchedAxisZ)
	end
end

for _, part: BasePart in pairs(OUT_FOLDER:GetChildren()) do
	if not part:IsA("BasePart") then continue end
	outOfBoundsMaid[part] = {}
	outOfBoundsMaid[part]["maid"] = Maid.new()
	outOfBoundsMaid[part]["saved"] = Maid.new()

	local function GiveOutOfBoundsMaid()
		outOfBoundsMaid[part]["maid"]:Destroy()
		outOfBoundsMaid[part]["saved"]:Destroy()

		local gotIt = false

		outOfBoundsMaid[part]["maid"]:GiveTask(part.Touched:Connect(function(partThatTouched: BasePart)
			if not partThatTouched:IsDescendantOf(BALLS_FOLDER) then return end
			local ball = BallService:GetBall(partThatTouched)


			outOfBoundsMaid[part]["saved"]:GiveTask(ball.Data.PlayerOnBall:GetPropertyChangedSignal("Value"):Connect(function()
				-- if ball.Data.PlayerOnBall.Value == nil then return end
				gotIt = true
				GiveOutOfBoundsMaid()
				return
			end))

			task.wait(0.175)
			if gotIt then return end
			task.spawn(HandleTouchedPart, partThatTouched)
			GiveOutOfBoundsMaid()
		end))
	end

	GiveOutOfBoundsMaid()
end
