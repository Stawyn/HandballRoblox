type BallObject = {
	Instance: BasePart,
	CanTouch: boolean,
	SetPiece: "Home" | "Away",
	Data: {
		["LastShoot"]: ObjectValue,
		["PlayerOnBall"]: ObjectValue,
		["LastShootShoot"]: ObjectValue,
		["LastPlayerOnBall"]: ObjectValue
	}
}

local BallService = {}
BallService.__index = BallService

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local HTTPService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Utils = ReplicatedStorage:WaitForChild("Utils")
local Maid = require(Utils:WaitForChild("Maid"))
local Weld = require(script:WaitForChild("Weld"))
local Kick = require(script:WaitForChild("Kick"))
local Offside = require(script:WaitForChild("Offside"))
local NoDelay = require(script:WaitForChild("NoDelay"))
local Ping = require(script:WaitForChild("Ping"))
local TimerModule = require(ServerScriptService:WaitForChild("Services"):WaitForChild("RefereeService"):WaitForChild("TimerModule"))

local GAMEINFO_FOLDER = ReplicatedStorage:WaitForChild("GameInfo")
local gameEvents = ReplicatedStorage:WaitForChild("Bindable"):WaitForChild("GameEvents")

local ballMaid = Maid.new()
local keeperWeldMaid = Maid.new()
local ballsFolder: Folder = workspace:WaitForChild("Core"):WaitForChild("Balls")
local matchValue: StringValue = workspace:WaitForChild("Core"):WaitForChild("Stats"):WaitForChild("Match")

local keeperGrip = CFrame.new(0,-0.5,-1.1)
local grip = CFrame.new(0,-2,-1.5)
local BOX_POSITION_Z = 219
local BOX_POSITION_X = 110
local GOALKICK_ZAXIS = 266.5
local GOALKICK_PART = ServerStorage:WaitForChild("GameSourceServer"):WaitForChild("GoalKick")

local ballsTable = {}
local ballHoldTime = {}

function CheckPlayerInBox(player: Player)
	local character = player.Character or player.CharacterAdded:Wait()
	
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	local box = player.Team.Name:find("Home") and 1 or 0

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

function DeleteAllSetPieces(ballObject: BallObject)
	if workspace:FindFirstChild("Home") then
		workspace.Home:Destroy()
	end
	if workspace:FindFirstChild("Away") then
		workspace.Away:Destroy()
	end
	if ballObject.Instance:FindFirstChild("SetPiece") then
		ballObject.Instance.SetPiece:Destroy()
	end
	if ballObject.Instance:FindFirstChild("GoalKick") then
		ballObject.Instance.GoalKick:Destroy()
	end
	ballObject.SetPiece = nil
end

function BallService.new(spawning: Player | Vector3, setPiece: "Home" | "Away"): BallObject
	local self: BallObject = setmetatable({}, BallService)

	local newBall: BallInstance = ServerStorage:WaitForChild("Ball"):Clone()
	newBall.Name = HTTPService:GenerateGUID()
	
	newBall:SetAttribute("Picked", false)
	
	newBall.CollisionGroup = "Ball"
	if typeof(spawning) == "Instance" then
		newBall.CFrame = spawning.Character.HumanoidRootPart.CFrame
	else
		newBall.Position = spawning
	end
	newBall.Parent = ballsFolder
	self.Instance = newBall
	self.CanTouch = true
	self.Data = {}
	self.SetPiece = setPiece
	self.Data.LastShoot = Instance.new("ObjectValue")
	self.Data.PlayerOnBall = Instance.new("ObjectValue")
	self.Data.LastShootShoot = Instance.new("ObjectValue")
	self.Data.LastPlayerOnBall = Instance.new("ObjectValue")
	
	local flicks = 0
	
	local function onTouch(player: Player, intDistance: number)
		if not player then return end
		if not self.CanTouch then return end
		if not player.Character then return end
		if not player.Character:FindFirstChild("Humanoid") or player.Character.Humanoid.Health <= 0 then return end
		if player.Character:FindFirstChild("HumanoidRootPart") and player.Character.HumanoidRootPart:FindFirstChild("BallWeld") then return end
		if matchValue.Value ~= "Training" and not string.find(player.Team.Name, "Home") and not string.find(player.Team.Name, "Away") and not string.find(player.Team.Name, "Officials") then return end
		if newBall:GetAttribute("Picked") then return end
				
		self.CanTouch = false
		local Tackled = false
		if self.Data.PlayerOnBall.Value ~= nil then
			local existingWeld: Weld = self.Data.PlayerOnBall.Value and self.Data.PlayerOnBall.Value.Character.HumanoidRootPart:FindFirstChild("BallWeld")
			
			if existingWeld and existingWeld.Part1 then
				local targetPlayer = Players:GetPlayerFromCharacter(existingWeld.Part1.Parent)
				if targetPlayer and targetPlayer ~= player then
					existingWeld:Destroy()
					self.Data.LastPlayerOnBall.Value = targetPlayer
				end
			end
		end
		
		if newBall:FindFirstChild("BodyForce") then newBall.BodyForce:Destroy() end
		Weld(newBall, player.Character)
		self.Data.PlayerOnBall.Value = player
		if newBall:FindFirstChild("Trail") then
			newBall.Trail.Color = ColorSequence.new(player.TeamColor.Color)
		end
		
		if self.Data.LastShoot.Value ~= player then
			ballHoldTime[player] = os.clock()
		end
		
		if not Tackled and self.Data.LastShoot.Value == player then
			flicks += 1
		else
			flicks = 0
		end
		
		if flicks > 3 then
			local ballPosition = self.Instance.Position
			gameEvents:Fire("Flick Spam", self.Data.PlayerOnBall.Value, ballPosition, self.Instance)
		end
		
		--[[
		if not Tackled and self.Data.LastShoot.Value == player then
			task.wait(0.3)
		else
			task.wait(0.5)
		end
		--]]
		task.wait(0.5)
		
		self.CanTouch = true
	end
	
	local function HandleGoalkeeperPosession(homePosession: boolean)
		local setPiecePart = GOALKICK_PART:Clone()
		setPiecePart.BrickColor = homePosession and BrickColor.new("Really blue") or BrickColor.new("Really red")
		setPiecePart.Position = homePosession and Vector3.new(0, 0.5, GOALKICK_ZAXIS) or Vector3.new(0, 0.5, -GOALKICK_ZAXIS)	
		
		gameEvents:Fire("Goalkeeper Possession", setPiecePart, newBall)
	end
	
	ballMaid:GiveTask(newBall.Touched:Connect(function(partThatTouched: BasePart)
		local distance = (newBall.Position - partThatTouched.Position).Magnitude
		local player: Player? = Players:GetPlayerFromCharacter(partThatTouched.Parent)
		
		if not player then return end
		if partThatTouched.Name:find("Arm") and not player.Team.Name:find("Goalkeeper") then
			return 
		end
		if player.Character:FindFirstChild("HumanoidRootPart") and player.Character.HumanoidRootPart:FindFirstChild("BallWeld") then return end
		if not self.CanTouch then return end
		if self.SetPiece == "Home" and player.Team.Name:find("Away") then return end
		if self.SetPiece == "Away" and player.Team.Name:find("Home") then return end
		if self.Data.PlayerOnBall.Value ~= nil then
			if self.SetPiece == "Home" and player.Team.Name:find("Home") then
				DeleteAllSetPieces(self)
			elseif self.SetPiece == "Away" and player.Team.Name:find("Away") then
				DeleteAllSetPieces(self)
			end
		end
		if player.leaderstats.Ping.Value >= 500 then return end
		
		local intDistance = math.floor(distance * 10) / 10
		onTouch(player, intDistance)
	end))
	
	newBall.BallRemote.OnServerEvent:Connect(function(player, argument)
		if not player.Character:FindFirstChild("KeeperTool") then return end
		if not player.Character:FindFirstChild("HumanoidRootPart") then return end
		if not player.Character.HumanoidRootPart:FindFirstChild("BallWeld") then return end
		if player.Character.HumanoidRootPart.BallWeld.Part0 ~= newBall then return end
		if argument ~= "Keeper" then return end
		if player.Team.Name:find("Home") and self.Data.LastPlayerOnBall.Value and self.Data.LastPlayerOnBall.Value.Team.Name:find("Home") then return end
		if player.Team.Name:find("Away") and self.Data.LastPlayerOnBall.Value and self.Data.LastPlayerOnBall.Value.Team.Name:find("Away") then return end
		keeperWeldMaid:Destroy()
		
		
		newBall:SetAttribute("Picked", true)
		player.Character.HumanoidRootPart.BallWeld.C1 = keeperGrip
		HandleGoalkeeperPosession(player.Team.Name:find("Home"))

		local thread = task.spawn(function()
			local seconds = 8
			newBall.KeeperSeconds.Enabled = true
			newBall.KeeperSeconds.Counter.Text = seconds
			
			while seconds > 0 do
				task.wait(1)
				seconds -= 1
				newBall.KeeperSeconds.Counter.Text = seconds
			end
			
			newBall.KeeperSeconds.Enabled = false
			newBall:SetAttribute("Picked", false)
			player.Character.HumanoidRootPart.BallWeld.C1 = grip
			if newBall:FindFirstChild("GoalKick") then
				newBall.GoalKick:Destroy()
			end
		end)
		
		keeperWeldMaid:GiveTask(RunService.Stepped:Connect(function()
			local playerIsInBox = CheckPlayerInBox(player)
			if not playerIsInBox then
				newBall.KeeperSeconds.Enabled = false
				keeperWeldMaid:Destroy()
				task.cancel(thread)
				newBall:SetAttribute("Picked", false)
				player.Character.HumanoidRootPart.BallWeld.C1 = grip
				if newBall:FindFirstChild("GoalKick") then
					newBall.GoalKick:Destroy()
				end
			end
		end))
		
		keeperWeldMaid:GiveTask(player.Character.HumanoidRootPart.ChildRemoved:Connect(function(child: Weld)
			if child.Name ~= "BallWeld" then return end
			newBall.KeeperSeconds.Enabled = false
			keeperWeldMaid:Destroy()
			task.cancel(thread)
			if newBall:FindFirstChild("GoalKick") then
				newBall.GoalKick:Destroy()
			end
		end))
	end)
	
	task.spawn(Offside, self)
	task.spawn(NoDelay, self.Instance)
	-- task.spawn(Ping, self)
	
	ballsTable[newBall] = {}
	ballsTable[newBall].self = self
	return self
end

function BallService:Clear()
	ballsFolder:ClearAllChildren()
	for _, player: Player in pairs(Players:GetPlayers()) do
		if not player.Character then continue end
		if not player.Character:FindFirstChild("HumanoidRootPart") then continue end
		if not player.Character.HumanoidRootPart:FindFirstChild("BallWeld") then continue end
		player.Character.HumanoidRootPart.BallWeld:Destroy()
	end
	ballMaid:Destroy()
	table.clear(ballHoldTime)
	table.clear(ballsTable)
end

function BallService:Kick(player: Player, BallInstance: BasePart, Properties: ShootProperties)
	if not ballsTable[BallInstance] then return end
	local ballObject = ballsTable[BallInstance].self
	local totalTimeWithTheBall = ballHoldTime[player]
	
	local velocity, releasePosition, isDriven = Kick.new(ballObject.Instance, player.Character, Properties, totalTimeWithTheBall)
	if not velocity or not releasePosition then return end
	if ballObject.Instance:GetAttribute("Picked") then
		ballObject.Instance:SetAttribute("Picked", false)
	end
	
	GAMEINFO_FOLDER.Taker.Value = ""
	if player:GetAttribute("SetPiece") == true then
		player:SetAttribute("SetPiece", false)
		TimerModule:Resume()
	end
	DeleteAllSetPieces(ballObject)
	
	
	if player.Character:FindFirstChild("HumanoidRootPart"):FindFirstChild("BallWeld") then 
		player.Character.HumanoidRootPart.BallWeld:Destroy() 
	end
	ballObject.Instance.Kick:Play()
	ballObject.Data.PlayerOnBall.Value = nil
	
	if isDriven then
		task.spawn(function()
			Kick:HandleDriven(ballObject.Instance)
		end)
	end
	
	ballObject.Data.LastPlayerOnBall.Value = player
	if ballObject.Data.LastShoot.Value ~= ballObject.Data.LastShootShoot.Value then
		ballObject.Data.LastShootShoot.Value = ballObject.Data.LastShoot.Value
	end
	ballObject.Data.LastShoot.Value = player
	ballObject.Instance.Position = releasePosition
	ballObject.Instance.AssemblyAngularVelocity = Vector3.new()
	ballObject.Instance.AssemblyLinearVelocity = velocity
end

function BallService:RemoveWeld()
	if self.Data.PlayerOnBall.Value ~= nil then
		local existingWeld: Weld = self.Data.PlayerOnBall.Value.Character.HumanoidRootPart:FindFirstChild("BallWeld")

		if existingWeld and existingWeld.Part1 then
			local targetPlayer = Players:GetPlayerFromCharacter(existingWeld.Part1.Parent)
			if targetPlayer then
				existingWeld:Destroy()
				self.Data.LastPlayerOnBall.Value = targetPlayer
			end
		end
	end
end

function BallService:GetBall(part: BasePart): BallObject
	if not ballsTable[part] then return end
	return ballsTable[part].self
end

function BallService:RemoveSetPiece()
	self.SetPiece = nil
end

function BallService:RemoveAllBallsSetPiece()
	for _, ball in pairs(ballsTable) do
		ball.self.SetPiece = nil
	end
end

return BallService

