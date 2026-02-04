local KeeperController = {}

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Maid = require(game:GetService("ReplicatedStorage"):WaitForChild("Utils"):WaitForChild("Maid"))
local R6InverseKinematic = require(game:GetService("ReplicatedStorage"):WaitForChild("Utils"):WaitForChild("IKB"):WaitForChild("ArmInverseKinematic"))

local localPlayer: Player = Players.LocalPlayer 
playerGui = localPlayer.PlayerGui
local keeperFolderUI = playerGui:WaitForChild("Mobile"):WaitForChild("Frame"):WaitForChild("Keeper")

local keeperMaid = Maid.new()
local ballWeldedMaid = Maid.new()
local IKMaid = Maid.new()
local cooldown: boolean = false
local diving = false

local rightArmIK = nil
local leftArmIK = nil

local BOX_POSITION_Z = 219
local BOX_POSITION_X = 110

function SolveRightArm(dotProduct: number, ball: BasePart)
	if rightArmIK then
		rightArmIK:Destroy()
	end	
	rightArmIK = R6InverseKinematic.new(localPlayer.Character, "Right")

	local rightArmPosition: Vector3 = localPlayer.Character["Right Arm"].Position
	rightArmIK:Solve(ball.Position)
end

function SolveLeftArm(dotProduct: number, ball: BasePart)
	if leftArmIK then
		leftArmIK:Destroy()
	end	
	leftArmIK = R6InverseKinematic.new(localPlayer.Character, "Left")

	local leftArmPosition: Vector3 = localPlayer.Character["Left Arm"].Position
	leftArmIK:Solve(ball.Position)
end

function RegisterIKMaid()
	IKMaid:GiveTask(RunService.Stepped:Connect(function()
		local character = localPlayer.Character
		local closestBall = GetClosestBall()

		if closestBall then
			local torsoLookVector: Vector3 = character.Torso.CFrame.LookVector
			local lookAtBall: CFrame = CFrame.lookAt(character.Torso.Position, closestBall.Position)
			local dotProduct = torsoLookVector:Dot(lookAtBall.LookVector)

			if dotProduct > 0 then
				-- Ball is in front
				SolveRightArm(dotProduct, closestBall)
				SolveLeftArm(dotProduct, closestBall)
			end
		end
	end))
end

function ResetInverseKinematics()
	if rightArmIK then rightArmIK:Destroy() end	
	if leftArmIK then leftArmIK:Destroy() end
end

function GetClosestBall(): BasePart?
	local torso = localPlayer.Character.Torso 
	if not torso then return end
	local closestBall: BasePart = nil
	local closestMagnitude: number = math.huge

	for index, ball in pairs(workspace:WaitForChild("Core"):WaitForChild("Balls"):GetChildren()) do
		local magnitude = (ball.Position - torso.Position).Magnitude
		if magnitude < closestMagnitude then
			closestMagnitude = magnitude
			closestBall = ball
		end
	end

	return closestBall
end

function KeeperController:ResetCooldown()
	diving = false
	cooldown = false
	ResetInverseKinematics()
	IKMaid:Destroy()
end

function KeeperController:GetUp()
	local character: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	local humanoid: Humanoid = character:WaitForChild("Humanoid")
	local humanoidRootPart: BasePart = character:WaitForChild("HumanoidRootPart")
	if humanoidRootPart:FindFirstChild("BodyForce") then
		humanoidRootPart:FindFirstChild("BodyForce"):Destroy()
	end
	if humanoidRootPart:FindFirstChild("BodyGyro") then
		humanoidRootPart:FindFirstChild("BodyGyro"):Destroy()
	end
	
	local DENSITY = 0.7
	local FRICTION = 0.5
	local ELASTICITY = 0
	local FRICTION_WEIGHT = 0.3
	local ELASTICITY_WEIGHT = 0.7

	local physProperties = PhysicalProperties.new(DENSITY, FRICTION, ELASTICITY, FRICTION_WEIGHT, ELASTICITY_WEIGHT)
	character.Head.CustomPhysicalProperties = physProperties
	
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	humanoidRootPart.AssemblyLinearVelocity = Vector3.new()
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	ballWeldedMaid:Destroy()
	cooldown = false
	diving = false
	
	IKMaid:Destroy()
	ResetInverseKinematics()
end

function CheckPlayerInBox()
	local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	local box = localPlayer.Team.Name:find("Home") and 1 or 0

	if box > 0 then
		return (humanoidRootPart.Position.X < BOX_POSITION_X and 
			humanoidRootPart.Position.X > -BOX_POSITION_X and 
			humanoidRootPart.Position.Z > BOX_POSITION_Z)
	else
		return (humanoidRootPart.Position.X < BOX_POSITION_X and 
			humanoidRootPart.Position.X > -BOX_POSITION_X and 
			humanoidRootPart.Position.Z < -BOX_POSITION_Z)
	end
end

function KeeperController:DiveTo(side: "L" | "R")
	if not CheckPlayerInBox() then return end
	
	local character: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	local humanoid: Humanoid = character:WaitForChild("Humanoid")
	local humanoidRootPart: BasePart = character:WaitForChild("HumanoidRootPart")
	if cooldown then return end
	if humanoid.Health <= 0 then return end
	if humanoid.PlatformStand then return end
	if humanoidRootPart:FindFirstChild("BodyVelocity") then return end
	diving = true
	RegisterIKMaid()
	local finalCFrame: CFrame
	
	task.spawn(function()
		local DENSITY = 0.7
		local FRICTION = 0.5
		local ELASTICITY = 0
		local FRICTION_WEIGHT = 0.3
		local ELASTICITY_WEIGHT = 1
		
		local physProperties = PhysicalProperties.new(DENSITY, FRICTION, ELASTICITY, FRICTION_WEIGHT, ELASTICITY_WEIGHT)
		character.Head.CustomPhysicalProperties = physProperties
	end)

	local rightVector: Vector3
	if side == "R" then
		finalCFrame = humanoidRootPart.CFrame * CFrame.Angles(0, 0, -math.pi/2)
		
		rightVector = humanoidRootPart.CFrame.RightVector * 1700
		humanoidRootPart.CFrame *= CFrame.Angles(0, 0, -math.pi / 3)
	else
		finalCFrame = humanoidRootPart.CFrame * CFrame.Angles(0, 0, math.pi/2)
		
		rightVector = -humanoidRootPart.CFrame.RightVector * 1700
		humanoidRootPart.CFrame *= CFrame.Angles(0, 0, math.pi / 3)
	end
	cooldown = true
	humanoid.PlatformStand = true
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	
	local bodyGyro = Instance.new("BodyGyro")
	bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	bodyGyro.CFrame = finalCFrame
	bodyGyro.P = 5000
	bodyGyro.Parent = humanoidRootPart
	
	
	local bodyForce: BodyForce = Instance.new("BodyForce")
	bodyForce.Force = rightVector
	bodyForce.Parent = humanoidRootPart
	
	Debris:AddItem(bodyForce, 0.35)
	-- Debris:AddItem(bodyGyro, 0.65)
	
	if humanoidRootPart:FindFirstChild("BallWeld") then
		task.spawn(function()
			local ballInstance = humanoidRootPart.BallWeld.Part0
			if not ballInstance then return end
			ballInstance.BallRemote:FireServer("Keeper")
		end)
	else
		ballWeldedMaid:GiveTask(humanoidRootPart.ChildAdded:Connect(function(child: Weld)
			if not child:IsA("Weld") then return end
			local ballInstance = child.Part0
			if not ballInstance then return end
			ballInstance.BallRemote:FireServer("Keeper")
		end))
	end

	local alreadyGotUp: boolean = false
	keeperMaid:GiveTask(UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
		if gameProcessedEvent then return end
		if not humanoid.PlatformStand then return end
		if input.KeyCode ~= Enum.KeyCode.R then return end

		keeperMaid:Destroy()
		self:GetUp()
		alreadyGotUp = true
	end))

	keeperMaid:GiveTask(keeperFolderUI.GetUp.MouseButton1Click:Connect(function()
		if not humanoid.PlatformStand then return end

		keeperMaid:Destroy()
		self:GetUp()
		alreadyGotUp = true
	end))

	task.wait(2)
	if alreadyGotUp then return end
	if not humanoid.PlatformStand then return end
	keeperMaid:Destroy()
	self:GetUp()
end

return KeeperController
