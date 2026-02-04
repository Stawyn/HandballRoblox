local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local KeeperTool = {}
local ClientNetwork = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Implementation"):WaitForChild("ClientNetwork"))
local Maid = require(game:GetService("ReplicatedStorage"):WaitForChild("Utilities"):WaitForChild("Maid"))
local Animations = require(game:GetService("ReplicatedStorage"):WaitForChild("Utilities"):WaitForChild("ABHAnimations"))
local Janitor = require(game:GetService("ReplicatedStorage"):WaitForChild("Utilities"):WaitForChild("Janitor"))
local VectorLib = require(game:GetService("ReplicatedStorage"):WaitForChild("Utilities"):WaitForChild("Vector"))
local SharedAttributes = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Implementation"):WaitForChild("SharedAttributes"))
local MathLib = require("../../../Utilities/Math")
local InputSystem = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Implementation"):WaitForChild("InputSystem"))

local localPlayer = Players.LocalPlayer :: Player
local BALLS_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Balls")

local MAX_REACTION = 1
local MIN_REACTION = 0
local MAX_ITERATIONS = 100
local MIN_PERCENTAGE_RATE = 0
local MAX_DIST = 15
local interactionCooldown = false
local GOALKEEPER_COOLDOWN = 0.75

local MAX_GOALKEEPER_MAGNTUDE = 30
local MAX_PREDICT_MAGNITUDE = 45

function getNearestBall() : BasePart?
	if not localPlayer.Character then
		return nil
	end
	
	local hrp = localPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart
	if not hrp then
		return nil
	end
	
	local closest
	local distance = math.huge
	for _, ball in BALLS_FOLDER:GetChildren() do
		if ball:IsA("MeshPart") and ball.CanTouch == true then
			local distanceToBall = (ball.Position - hrp.Position).Magnitude
			if distanceToBall < distance then
				distance = distanceToBall
				closest = ball
			end
		end
	end
	
	return closest
end

function getBallResultingForce(ball: BasePart)
	local resultingForce = Vector3.new(0, -(workspace.Gravity * ball:GetMass()), 0)
	for _, force in ball:GetChildren() do
		if force:IsA("VectorForce") then
			if force.Name == "ResistanceForce" then -- We're alreading taking into consideration
				continue
			end
			resultingForce += force.Force
		end
	end
	
	return resultingForce
end

function evaluateBallTrajectory(s0: vector, v0: vector, p: vector, verticalForce: Vector3, m: number, t: number)
	local k = SharedAttributes:GetKDrag()
	local acceleration = verticalForce / m
	
	local exp = math.exp(-(k/m)*t)
	
	local x = s0.x + v0.x * (m/k) * (1 - exp)
	local y = s0.y + v0.y * t + 0.5 * acceleration.Y * math.pow(t, 2)
	y = math.max(y, p.y - 3)
	
	local z = s0.z + v0.z * (m/k) * (1 - exp)
	
	local s = vector.create(x,y,z)
	return s
end

function distanceFunction(s0: vector, v0: vector, verticalForce: Vector3, m: number, t: number, p: vector)
	local s = evaluateBallTrajectory(s0, v0, p, verticalForce, m, t)
	local d = (s - p)
	return vector.dot(d,d)
end

function LimitVector(v: vector)
	if vector.magnitude(v) == 0 then
		return v 
	end
	
	local multiplier = math.min(vector.magnitude(v), MAX_PREDICT_MAGNITUDE)
	return vector.normalize(v) * multiplier
end

function KeeperTool:Initialize(tool: Tool)
	local instanceJanitor = Janitor.new()	
	local focusedJanitor = Janitor.new()
	local focusedConnection = Janitor.new()
	local toolJanitor = Janitor.new()
	local keeperJanitor = Janitor.new()
	local cooldown = false
	local thread: thread?
	local predictSide: "Left" | "Right" = "Right"
	
	toolJanitor:LinkToInstance(tool)
	instanceJanitor:LinkToInstance(tool)
	
	local function resetThread()
		if thread ~= nil then
			task.cancel(thread)
			thread = nil
		end
		
		cooldown = false
	end
	
	local function dive(humanoid: Humanoid, humanoidRootPart: BasePart)
		local sideVector = if predictSide == "Right" then humanoidRootPart.CFrame.RightVector else -humanoidRootPart.CFrame.RightVector
		local diveVelocity = sideVector.Unit * vector.create(1, 0, 1) * MAX_GOALKEEPER_MAGNTUDE
		local rotation = if predictSide == "Right" then -math.pi/2 else math.pi/2 

		if humanoidRootPart:FindFirstChild("KeeperAlignOrientation") then
			return
		end
		if humanoidRootPart:FindFirstChild("KeeperLinearVelocity") then
			return
		end
		cooldown = true

		local attachment = humanoidRootPart:WaitForChild("RootAttachment") :: Attachment

		local linearVelocity = Instance.new("LinearVelocity")
		linearVelocity.Name = "KeeperLinearVelocity"
		linearVelocity.ForceLimitsEnabled = false
		linearVelocity.Attachment0 = attachment
		linearVelocity.MaxForce = math.huge
		linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
		linearVelocity.VectorVelocity = diveVelocity

		local goalCFrame = humanoidRootPart.CFrame * CFrame.Angles(0, 0, rotation)

		local alignOrientation = Instance.new("AlignOrientation")
		alignOrientation.Name = "KeeperAlignOrientation"
		alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
		alignOrientation.RigidityEnabled = true
		alignOrientation.Responsiveness = 1e5
		alignOrientation.CFrame = CFrame.new()
		alignOrientation.Attachment0 = attachment

		linearVelocity.Parent = humanoidRootPart
		alignOrientation.Parent = humanoidRootPart

		TweenService:Create(alignOrientation, TweenInfo.new(0.25), {
			CFrame = goalCFrame,
		}):Play()

		Debris:AddItem(linearVelocity, 0.5)
		Debris:AddItem(alignOrientation, 0.5)
		task.wait(0.5)
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		task.wait(0.5)
		cooldown = false
	end
	
	local function togglePredictMode(humanoid: Humanoid, humanoidRootPart: BasePart)
		if cooldown then
			return
		end

		local keeperPosition = VectorLib:Vector3ToVectorLib(humanoidRootPart.Position)
		local runDirection = VectorLib:Vector3ToVectorLib(humanoid.MoveDirection)
		runDirection = vector.normalize(runDirection) * vector.create(1, 0, 1)

		local nearestBall = getNearestBall() :: MeshPart
		if not nearestBall then
			coroutine.wrap(dive)(humanoid, humanoidRootPart)
			return
		end

		local s0 = VectorLib:Vector3ToVectorLib(nearestBall.Position)
		local v0 = VectorLib:Vector3ToVectorLib(nearestBall.AssemblyLinearVelocity)
		local m = nearestBall:GetMass()
		local verticalForce = getBallResultingForce(nearestBall)

			--[[
			This is the function we want to minimize, i.e., we want to find t such that:

			f(t) = ||s(t) - keeperPosition||Â² 
			is the smallest possible
			--]]
		local function f(t: number)
			return distanceFunction(s0, v0, verticalForce, m, t, keeperPosition)
		end

		local optimalTime = MathLib:TernarySearch(f, MIN_REACTION, MAX_REACTION)
		local optimalPosition = evaluateBallTrajectory(s0, v0, keeperPosition, verticalForce, m, optimalTime)

		local ballDirection = optimalPosition - keeperPosition
		if vector.magnitude(ballDirection) > MAX_DIST then
			coroutine.wrap(dive)(humanoid, humanoidRootPart)
			return
		end


		local unitDirection = vector.normalize(optimalPosition - keeperPosition) * vector.create(1, 0, 1)
		local dot = vector.dot(runDirection, unitDirection)

		local rightVector = VectorLib:Vector3ToVectorLib(humanoidRootPart.CFrame.RightVector)
		rightVector = vector.normalize(rightVector)
		--local rotation = if vector.dot(rightVector, ballDirection) > 0 then -math.pi/2 else math.pi/2
		local ballSide = if vector.dot(rightVector, ballDirection) > 0 then "Right" else "Left"
		local rotation = if predictSide == "Right" then -math.pi/2 else math.pi/2 
		local sideDot = vector.dot(rightVector, ballDirection)

		if dot >= MIN_PERCENTAGE_RATE and ballSide == predictSide then
			if humanoidRootPart:FindFirstChild("KeeperAlignOrientation") then
				return
			end
			if humanoidRootPart:FindFirstChild("KeeperLinearVelocity") then
				return
			end
			cooldown = true

			local reference = Instance.new("Part")
			reference.Shape = Enum.PartType.Ball
			reference.Material = Enum.Material.ForceField
			reference.BrickColor = BrickColor.White()
			reference.Size = Vector3.new(1.75,1.75,1.75)
			reference.Anchored = true
			reference.CanCollide = false
			reference.Position = VectorLib:VectorLibToVector3(optimalPosition)
			reference.Parent = workspace
			Debris:AddItem(reference, 1)

			local velocity = ballDirection / optimalTime
			local velocityNeeded = LimitVector(velocity)
			local attachment = humanoidRootPart:WaitForChild("RootAttachment") :: Attachment

			local linearVelocity = Instance.new("LinearVelocity")
			linearVelocity.Name = "KeeperLinearVelocity"
			linearVelocity.ForceLimitsEnabled = false
			linearVelocity.Attachment0 = attachment
			linearVelocity.MaxForce = math.huge
			linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
			linearVelocity.VectorVelocity = velocityNeeded

			local goalCFrame = humanoidRootPart.CFrame * CFrame.Angles(0, 0, rotation)

			local alignOrientation = Instance.new("AlignOrientation")
			alignOrientation.Name = "KeeperAlignOrientation"
			alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
			alignOrientation.RigidityEnabled = true
			alignOrientation.Responsiveness = 1e5
			alignOrientation.CFrame = CFrame.new()
			alignOrientation.Attachment0 = attachment

			linearVelocity.Parent = humanoidRootPart
			alignOrientation.Parent = humanoidRootPart

			TweenService:Create(alignOrientation, TweenInfo.new(0.25), {
				CFrame = goalCFrame,
			}):Play()

			Debris:AddItem(linearVelocity, 0.5)
			Debris:AddItem(alignOrientation, 0.5)
			task.wait(0.5)
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			task.wait(0.5)
			cooldown = false
		else
			coroutine.wrap(dive)(humanoid, humanoidRootPart)
		end
	end
	
	local function initPredict()
		if interactionCooldown then
			return
		end
		interactionCooldown = true
		keeperJanitor:Cleanup()

		local character = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		local humanoidRootPart = character:WaitForChild("HumanoidRootPart") :: BasePart

		resetThread()

		togglePredictMode(humanoid, humanoidRootPart)
		task.wait(GOALKEEPER_COOLDOWN) -- cooldown
		interactionCooldown = false
	end
	
	InputSystem.Actions.Goalkeeper["Left Predict"].Pressed:Connect(function()
		predictSide = "Left"
		initPredict()
	end)
	
	InputSystem.Actions.Goalkeeper["Right Predict"].Pressed:Connect(function()
		predictSide = "Right"
		initPredict()
	end)
	
	tool.Equipped:Connect(function()
		local character = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		
		ClientNetwork.GoalkeeperEvent:Save(true)
		InputSystem.Contexts.Golkeeper.Enabled = true
		keeperJanitor:Cleanup()
		humanoid.WalkSpeed = SharedAttributes:GetGoalkeeperSpeed()
	end)
	
	tool.Unequipped:Connect(function()
		ClientNetwork.GoalkeeperEvent:Save(false)
		InputSystem.Contexts.Golkeeper.Enabled = false
		
		toolJanitor:Cleanup()
		focusedJanitor:Cleanup()
		keeperJanitor:Cleanup()
		
		resetThread()
		
		local character = localPlayer.Character
		if character then
			local humanoid = character:FindFirstChild("Humanoid") :: Humanoid
			if humanoid then
				humanoid.WalkSpeed = SharedAttributes:GetWalkSpeed()
			end
		end
	end)
	
	tool.Destroying:Connect(function()
		resetThread()
		focusedJanitor:Destroy()
	end)
end

return KeeperTool
