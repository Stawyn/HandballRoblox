local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local RunService = game:GetService("RunService")

local ABHLeague = require("../Implementation/ABHLeague")
local GameStatistics = require("../Systems/GameStatistics")
local ABHBall = require("../Systems/ABHBAll")
local Animations = require("../../../ReplicatedStorage/Utilities/ABHAnimations")
local SharedTypes = require("../../../ReplicatedStorage/Utilities/SharedTypes")
local SharedAttributes = require("../../../ReplicatedStorage/Modules/Implementation/SharedAttributes")
local Maid = require("../../../ReplicatedStorage/Utilities/Maid")
local Janitor = require("../../../ReplicatedStorage/Utilities/Janitor")
local Timer = require("../Implementation/Timer")
local Vector = require("../../../ReplicatedStorage/Utilities/Vector")
local Utils = require("../../../ReplicatedStorage/Utilities/Utils")

local ASSETS_FOLDER = ReplicatedStorage:WaitForChild("Assets") :: Folder
local BALLS_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Balls") :: Folder

local NETWORK_FOLDER = ReplicatedStorage:WaitForChild("Network") :: Folder
local BALL_EVENTS = NETWORK_FOLDER:FindFirstChild("BallEvents") :: RemoteEvent
local SWITCH_HAND_EVENT = NETWORK_FOLDER:WaitForChild("SwitchHands") :: RemoteEvent
local THROW_EVENT = NETWORK_FOLDER:WaitForChild("ThrowEvent") :: RemoteEvent
local GOALKEEPER_EVENT = NETWORK_FOLDER:WaitForChild("Goalkeeper") :: RemoteEvent
local REFEREE_EVENT = NETWORK_FOLDER:WaitForChild("Referee") :: RemoteEvent
local TACKLING_FUNCTION = NETWORK_FOLDER:WaitForChild("Tackling") :: RemoteFunction
local LEAGUE_EVENT = NETWORK_FOLDER:WaitForChild("LeagueEvent") :: RemoteEvent


local DATA_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Data")
local AWAY_SCORE = DATA_FOLDER:WaitForChild("AwayScore") :: NumberValue
local HOME_SCORE = DATA_FOLDER:WaitForChild("HomeScore") :: NumberValue
local BALL_TIMER = DATA_FOLDER:WaitForChild("BallTimer") :: BoolValue
local HOME_NAME = DATA_FOLDER:WaitForChild("HomeName") :: StringValue
local AWAY_NAME = DATA_FOLDER:WaitForChild("AwayName") :: StringValue
local MATCH_BOOLEAN = DATA_FOLDER:WaitForChild("Match") :: BoolValue
local MATCH_PAUSED = DATA_FOLDER:WaitForChild("MatchPaused") :: BoolValue
local TIMER = DATA_FOLDER:WaitForChild("Timer") :: NumberValue

HOME_NAME.Value = "HOME"
AWAY_NAME.Value = "AWAY"

local goalkeeperHitbox = {} :: {[number]: Instance}
local playersAnimTrack = {} :: {[number]: AnimationTrack}
local tacklingCooldown = {} :: {[number]: boolean}
local spawnedBall = {} :: {[number]: Instance}

BALL_EVENTS.OnServerEvent:Connect(function(player, action)
	local character = player.Character 
	if not character then
		return
	end

	local tool = player.Backpack:FindFirstChild("SpawnTool") or character:FindFirstChild("SpawnTool")
	if not tool then
		return
	end

	if action == "SpawnRequest" then
		local humanoidRoortPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not humanoidRoortPart then
			return
		end

		if spawnedBall[player.UserId] then
			spawnedBall[player.UserId]:Destroy()
		end

		local spawnPosition = humanoidRoortPart.CFrame
		local instance = ABHBall:Create(spawnPosition)
		spawnedBall[player.UserId] = instance

		if (player.Team :: Team).Name ~= "Officials" then
			instance.RefereeImmunity:Destroy()
		end

		instance.ForceField:Destroy()
	elseif action == "ClearRequest" then
		ABHLeague:DoCleaning()
	elseif action == "DropRequest" then
		if character:FindFirstChild("BallOwnership") then
			character.BallOwnership:Destroy()
		end
	end
end)

SWITCH_HAND_EVENT.OnServerEvent:Connect(function(player)
	local currentHand = player:GetAttribute("CurrentHand")
	local handToSwitch
	if currentHand == "R" then
		handToSwitch = "L"
	else
		handToSwitch = "R"
	end

	player:SetAttribute("CurrentHand", handToSwitch)

	local character = player.Character
	if character and character:FindFirstChild("BallOwnership") then
		local animator = character:WaitForChild("Humanoid"):WaitForChild("Animator") :: Animator
		local ballMotor6D = character:FindFirstChild("BallOwnership") :: Motor6D

		local animationTrack = animator:LoadAnimation(Animations.SwitchHands)
		animationTrack:Play()
		animationTrack.Stopped:Wait()

		local newHand
		if handToSwitch == "R" then
			newHand = character:FindFirstChild("Right Arm") :: BasePart
		else
			newHand = character:FindFirstChild("Left Arm") :: BasePart
		end

		ballMotor6D.Part0 = newHand
	end
end)

THROW_EVENT.OnServerEvent:Connect(function(player, power: number, directionData: SharedTypes.DirectionData)
	local fixedPower = math.clamp(power, 0, 100)

	local character = player.Character
	if not character then
		return
	end
	if not character:FindFirstChild("BallOwnership") then
		return
	end

	local ballMotor6D = character:FindFirstChild("BallOwnership") :: Motor6D
	local throwingHand = ballMotor6D.Part0 :: BasePart
	local instance = ballMotor6D.Part1 :: SharedTypes.ABHBallInstance
	local startingCFrame = throwingHand.CFrame

	ABHBall:Throw(player, instance, directionData, fixedPower)
end)

GOALKEEPER_EVENT.OnServerEvent:Connect(function(player, state: boolean)
	local existingHitbox = goalkeeperHitbox[player.UserId]
	if state then
		if existingHitbox then
			return
		end

		local character = player.Character
		if not character then
			return
		end

		local humanoid = character:FindFirstChild("Humanoid") :: Humanoid
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart

		if not humanoid then
			return
		end
		if not humanoidRootPart then
			return
		end

		local animator = humanoid:WaitForChild("Animator") :: Animator
		local animationTack = animator:LoadAnimation(Animations.KeeperAnimation)
		playersAnimTrack[player.UserId] = animationTack

		animationTack:Play()

		local hitboxInstance = Instance.new("Part")
		hitboxInstance.Name = "KeeperHitbox"
		hitboxInstance.Size = Vector3.new(8, 8, 5)
		hitboxInstance.Massless = true
		hitboxInstance.CanCollide = false
		hitboxInstance.Transparency = 1
		hitboxInstance.Parent = character

		local hitboxWeld = Instance.new("Motor6D")
		hitboxWeld.Name = "KeeperWeld"
		hitboxWeld.Part0 = humanoidRootPart
		hitboxWeld.Part1 = hitboxInstance
		hitboxWeld.C0 = CFrame.new(0, 0, -1.5)
		hitboxWeld.Parent = hitboxInstance

		goalkeeperHitbox[player.UserId] = hitboxInstance

		local detectionConnection
		detectionConnection = RunService.Heartbeat:Connect(function()
			if not hitboxInstance or not hitboxInstance.Parent then
				detectionConnection:Disconnect()
				return
			end

			local overlapParams = OverlapParams.new()
			overlapParams.FilterDescendantsInstances = {BALLS_FOLDER}
			overlapParams.FilterType = Enum.RaycastFilterType.Include

			local parts = workspace:GetPartBoundsInBox(hitboxInstance.CFrame, hitboxInstance.Size, overlapParams)
			for _, part in parts do
				if part:IsDescendantOf(BALLS_FOLDER) then
					ABHBall:HandleGoalkeeperSave(part :: SharedTypes.ABHBallInstance, humanoidRootPart.CFrame, player)
					break 
				end
			end
		end)
	else
		if existingHitbox then
			existingHitbox:Destroy()
			goalkeeperHitbox[player.UserId] = nil

			local character = player.Character
			if character then
				local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
				if humanoid then
					humanoid.WalkSpeed = SharedAttributes:GetWalkSpeed()
				end
			end

			if playersAnimTrack[player.UserId] then
				playersAnimTrack[player.UserId]:Stop()
				playersAnimTrack[player.UserId]:Destroy()
				playersAnimTrack[player.UserId] = nil
			end
		end
	end
end)

REFEREE_EVENT.OnServerEvent:Connect(function(player, data)
	if (player.Team :: Team).Name ~= "Officials" then
		return
	end

	if data.action == "ADD_GOAL" then
		if data.isHome then
			HOME_SCORE.Value += 1
		else
			AWAY_SCORE.Value += 1
		end
		if GameStatistics then
			pcall(function() GameStatistics.RecordTeamGoal(data.isHome) end)
		end
	elseif data.action == "REMOVE_GOAL" then
		if data.isHome then
			HOME_SCORE.Value = math.max(0, HOME_SCORE.Value - 1)
		else
			AWAY_SCORE.Value = math.max(0, AWAY_SCORE.Value - 1)
		end
		if GameStatistics and GameStatistics.DecrementTeamGoal then
			pcall(function() GameStatistics.DecrementTeamGoal(data.isHome) end)
		end
	elseif data.action == "TOGGLE_BALL_TIMER" then
		BALL_TIMER.Value = not BALL_TIMER.Value
	elseif data.action == "TOGGLE_TIMER" then
		Timer:Toggle(data.state)
	elseif data.action == "BEGIN_LEAGUE" then
		ABHLeague:BeginLeague()
	elseif data.action == "RESET_MATCH" then
		ABHLeague:Reset()
	elseif data.action == "PAUSE_MATCH" then
		ABHLeague:PauseMatch()
	elseif data.action == "RESUME_MATCH" then
		ABHLeague:ResumeMatch()
	elseif data.action == "TOGGLE_NAME" then
		if data.isHome then
			HOME_NAME.Value = data.teamName
			if GameStatistics then pcall(function() GameStatistics.NotifyTeamNameChange(data.teamName, true) end) end
		else
			AWAY_NAME.Value = data.teamName
			if GameStatistics then pcall(function() GameStatistics.NotifyTeamNameChange(data.teamName, false) end) end
		end
	elseif data.action == "RESET_TIMER" then
		Timer:Reset()
	elseif data.action == "REF_SPAWN_BALL" then		
		ABHLeague:SpawnFreeThrow(data.position :: Vector3, data.isHome :: boolean)
	elseif data.action == "REF_PENALTY" then
		ABHLeague:SpawnPenalty(data.isHome :: boolean, data.isHomeGLT :: boolean)
	elseif data.action == "REMOVE_BALLS" then
		ABHLeague:DoCleaning()
	end
end)

TACKLING_FUNCTION.OnServerInvoke = function(player: Player)
	local character = player.Character
	if not character then
		return
	end
	if character:FindFirstChild("BallOwnership") then
		return
	end

	local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
	if not humanoid then
		return
	end

	if tacklingCooldown[player.UserId] then
		return
	end

	tacklingCooldown[player.UserId] = true
	task.delay(1, function()
		tacklingCooldown[player.UserId] = nil
	end)

	local animator = humanoid:WaitForChild("Animator") :: Animator
	local currentHand = player:GetAttribute("CurrentHand")
	local animationToLoad
	if currentHand == "R" then
		animationToLoad = animator:LoadAnimation(Animations.RHandTackle)
	else
		animationToLoad = animator:LoadAnimation(Animations.LHandTackle)
	end

	local presumedHand
	if currentHand == "R" then
		presumedHand = character:FindFirstChild("Right Arm") :: BasePart
	else
		presumedHand = character:FindFirstChild("Left Arm") :: BasePart
	end

	if not presumedHand then
		return
	end


	animationToLoad.Priority = Enum.AnimationPriority.Action4
	animationToLoad:Play()	

	local tackleActive = true
	task.spawn(function()
		local overlapParams = OverlapParams.new()
		overlapParams.FilterDescendantsInstances = {BALLS_FOLDER, workspace}
		overlapParams.FilterType = Enum.RaycastFilterType.Include

		while tackleActive and character and character.Parent do
			local currentPresumedHand = if currentHand == "R" then character:FindFirstChild("Right Arm") else character:FindFirstChild("Left Arm")
			if not currentPresumedHand then break end

			local ballOverlap = OverlapParams.new()
			ballOverlap.FilterDescendantsInstances = {BALLS_FOLDER}
			ballOverlap.FilterType = Enum.RaycastFilterType.Include
			local parts = workspace:GetPartBoundsInBox(currentPresumedHand.CFrame, Vector3.new(4, 4, 4), ballOverlap)

			for _, part in parts do
				if part:IsDescendantOf(BALLS_FOLDER) and part.Name ~= "ForceField" then
					if part.Information.CanTackle.Value then
						ABHBall:HandleTackle(part :: SharedTypes.ABHBallInstance, player)
						tackleActive = false
						break
					end
				end
			end

			if not tackleActive then break end

			for _, otherPlayer in Players:GetPlayers() do
				if otherPlayer == player then continue end
				local otherChar = otherPlayer.Character
				if not otherChar then continue end

				local ballOwnership = otherChar:FindFirstChild("BallOwnership") :: Motor6D
				if ballOwnership then
					local dist = (currentPresumedHand.Position - otherChar.HumanoidRootPart.Position).Magnitude
					if dist < 3.5 then
						local abhBall = ballOwnership.Part1
						if abhBall and abhBall.Information.CanTackle.Value then
							ABHBall:HandleTackle(abhBall :: SharedTypes.ABHBallInstance, player)
							tackleActive = false
							break
						end
					end
				end
			end

			RunService.Heartbeat:Wait()
		end
	end)

	animationToLoad.Stopped:Wait()
	tackleActive = false
	tacklingCooldown[player.UserId] = nil
	return
end

LEAGUE_EVENT.OnServerEvent:Connect(function(player, action, ...)
	if action == "TEAM_FREE_THROW_CLIENT" then
		local ballName: string = ...
		local ball = BALLS_FOLDER:FindFirstChild(ballName)
		if not ball then
			return
		end

		local forceField = ball:FindFirstChild("ForceField")
		if not forceField then
			return
		end
		if forceField:GetAttribute("Took") == true then
			return
		end

		local teamName = (player.Team :: Team).Name
		if teamName:find("Substitutes") then
			return
		end
		if forceField:GetAttribute("isHome") == true and not teamName:find("Home")  then
			return
		end
		if forceField:GetAttribute("isHome") == false and not teamName:find("Away") then
			return
		end

		local character = player.Character
		if not character then
			return
		end

		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart
		if not humanoidRootPart then
			return
		end

		humanoidRootPart.CFrame = CFrame.new(Vector3.new(ball.Position.X, ball.Position.Y + 3, ball.Position.Z))
		forceField:SetAttribute("Took", true)
		forceField:SetAttribute("TakerUserId", player.UserId)
	elseif action == "SWITCH_TEAMS" then
		local teamName = ...

		if teamName == "Home" then
			player.Team = Teams["@Home Substitutes"]
		elseif teamName == "Away" then
			player.Team = Teams["@Away Substitutes"]
		end
	end
end)

Players.PlayerRemoving:Connect(function(p)
	tacklingCooldown[p.UserId] = nil
end)

return {}






