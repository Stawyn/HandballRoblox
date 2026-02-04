--[[
    ================================================================================
    MÓDULO: KeeperTool
    ================================================================================
    Descrição: Ferramenta de goleiro - sistema de previsão e mergulho.
               Calcula trajetória da bola e realiza defesa interceptando.
    
    Funcionalidades:
        - Previsão de trajetória (física com drag)
        - Mergulho lateral (Left/Right)
        - Cálculo de posição ótima de intercepção
        - Animações de defesa com rotação
        - Cooldown para evitar spam
    
    Constantes:
        - MAX_REACTION: 1s tempo máximo de previsão
        - MAX_DIST: 15 studs distância máxima
        - GOALKEEPER_COOLDOWN: 0.75s entre defesas
    
    Física:
        - Considera gravidade e força de arrasto (k drag)
        - Usa busca ternária para encontrar tempo ótimo
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: SERVIÇOS E DEPENDÊNCIAS
--// ============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local ClientNetwork = require("../../Implementation/ClientNetwork")
local Maid = require("../../../Utilities/Maid")
local Animations = require("../../../Utilities/ABHAnimations")
local Janitor = require("../../../Utilities/Janitor")
local VectorLib = require("../../../Utilities/Vector")
local SharedAttributes = require("../../Implementation/SharedAttributes")
local MathLib = require("../../../Utilities/Math")
local InputSystem = require("../../Implementation/InputSystem")

--// ============================================================================
--// SETOR: CONSTANTES
--// ============================================================================

local MAX_REACTION = 1
local MIN_REACTION = 0
local MAX_ITERATIONS = 100
local MIN_PERCENTAGE_RATE = 0
local MAX_DIST = 10  -- Bug #12/15: Reduzido de 15 para 10 studs
local GOALKEEPER_COOLDOWN = 0.75  -- Issue #7: Reduzido para 0.75s
local MAX_GOALKEEPER_MAGNITUDE = 25  -- Bug #12/15: Reduzido de 30 para 25
local MAX_PREDICT_MAGNITUDE = 30  -- Bug #12/15: Reduzido de 45 para 30

--// ============================================================================
--// SETOR: ESTADO
--// ============================================================================

local localPlayer = Players.LocalPlayer :: Player
local BALLS_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Balls")
local interactionCooldown = false

--// ============================================================================
--// SETOR: MÓDULO
--// ============================================================================

local KeeperTool = {}

--// ============================================================================
--// SETOR: FUNÇÕES DE FÍSICA
--// ============================================================================

--- Encontra a bola mais próxima do goleiro
local function getNearestBall(): BasePart?
	if not localPlayer.Character then return nil end
	
	local hrp = localPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart
	if not hrp then return nil end
	
	local closest = nil
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

--- Calcula força resultante na bola (gravidade + forças aplicadas)
local function getBallResultingForce(ball: BasePart): Vector3
	local resultingForce = Vector3.new(0, -(workspace.Gravity * ball:GetMass()), 0)
	
	for _, force in ball:GetChildren() do
		if force:IsA("VectorForce") then
			if force.Name == "ResistanceForce" then continue end
			resultingForce += force.Force
		end
	end
	
	return resultingForce
end

--- Avalia posição da bola no tempo t (com drag)
local function evaluateBallTrajectory(s0: vector, v0: vector, p: vector, verticalForce: Vector3, m: number, t: number): vector
	local k = SharedAttributes:GetKDrag()
	local acceleration = verticalForce / m
	local exp = math.exp(-(k/m)*t)
	
	local x = s0.x + v0.x * (m/k) * (1 - exp)
	local y = s0.y + v0.y * t + 0.5 * acceleration.Y * math.pow(t, 2)
	y = math.max(y, p.y - 3)
	local z = s0.z + v0.z * (m/k) * (1 - exp)
	
	return vector.create(x, y, z)
end

--- Função de distância para otimização
local function distanceFunction(s0: vector, v0: vector, verticalForce: Vector3, m: number, t: number, p: vector): number
	local s = evaluateBallTrajectory(s0, v0, p, verticalForce, m, t)
	local d = (s - p)
	return vector.dot(d, d)
end

--- Limita magnitude do vetor
local function LimitVector(v: vector): vector
	if vector.magnitude(v) == 0 then return v end
	local multiplier = math.min(vector.magnitude(v), MAX_PREDICT_MAGNITUDE)
	return vector.normalize(v) * multiplier
end

--// ============================================================================
--// SETOR: INICIALIZAÇÃO
--// ============================================================================

--- Inicializa a ferramenta de goleiro
function KeeperTool:Initialize(tool: Tool)
	local instanceJanitor = Janitor.new()	
	local focusedJanitor = Janitor.new()
	local focusedConnection = Janitor.new()
	local toolJanitor = Janitor.new()
	local keeperJanitor = Janitor.new()
	local cooldown = false
	local thread: thread? = nil
	local predictSide: "Left" | "Right" = "Right"
	
	toolJanitor:LinkToInstance(tool)
	instanceJanitor:LinkToInstance(tool)
	
	--- Reseta thread de cooldown
	local function resetThread()
		if thread ~= nil then
			task.cancel(thread)
			thread = nil
		end
		cooldown = false
	end
	
	--- Executa mergulho lateral simples
	local function dive(humanoid: Humanoid, humanoidRootPart: BasePart)
		local sideVector = if predictSide == "Right" then humanoidRootPart.CFrame.RightVector else -humanoidRootPart.CFrame.RightVector
		local diveVelocity = sideVector.Unit * vector.create(1, 0, 1) * MAX_GOALKEEPER_MAGNITUDE
		local rotation = if predictSide == "Right" then -math.pi/2 else math.pi/2 

		if humanoidRootPart:FindFirstChild("KeeperAlignOrientation") then return end
		if humanoidRootPart:FindFirstChild("KeeperLinearVelocity") then return end
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

		Debris:AddItem(linearVelocity, 0.3)
		Debris:AddItem(alignOrientation, 0.3)
		task.wait(0.25)
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		task.wait(0.25)
		cooldown = false
	end
	
	--- Modo de previsão - calcula intercepção
	local function togglePredictMode(humanoid: Humanoid, humanoidRootPart: BasePart)
		if cooldown then return end

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

		-- Função a minimizar: ||s(t) - keeperPosition||²
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
		local ballSide = if vector.dot(rightVector, ballDirection) > 0 then "Right" else "Left"
		local rotation = if predictSide == "Right" then -math.pi/2 else math.pi/2 

		if dot >= MIN_PERCENTAGE_RATE and ballSide == predictSide then
			if humanoidRootPart:FindFirstChild("KeeperAlignOrientation") then return end
			if humanoidRootPart:FindFirstChild("KeeperLinearVelocity") then return end
			cooldown = true

			-- Debug visual
			local reference = Instance.new("Part")
			reference.Shape = Enum.PartType.Ball
			reference.Material = Enum.Material.ForceField
			reference.BrickColor = BrickColor.White()
			reference.Size = Vector3.new(1.75, 1.75, 1.75)
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

			Debris:AddItem(linearVelocity, 0.3)
			Debris:AddItem(alignOrientation, 0.3)
			task.wait(0.25)
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			task.wait(0.25)
			cooldown = false
		else
			coroutine.wrap(dive)(humanoid, humanoidRootPart)
		end
	end
	
	--- Inicia previsão
	local function initPredict()
		if interactionCooldown then return end
		
		-- Bloqueia se o jogador estiver segurando a bola
		local character = localPlayer.Character
		if character and character:FindFirstChild("BallOwnership") then
			return
		end
		
		interactionCooldown = true
		keeperJanitor:Cleanup()

		local character = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		local humanoidRootPart = character:WaitForChild("HumanoidRootPart") :: BasePart

		resetThread()
		togglePredictMode(humanoid, humanoidRootPart)
		task.wait(GOALKEEPER_COOLDOWN)
		interactionCooldown = false
	end
	
	--// ============================================================================
	--// CONEXÕES
	--// ============================================================================
	
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