local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local SharedTypes = require("../../Utilities/SharedTypes")
local ABHAnimations = require("../../Utilities/ABHAnimations")
local Maid = require("../../Utilities/Maid")

local BOUNCE_COOLDOWN = 0.25
local BALLS_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Balls") :: Folder
local MATCH_PAUSED = workspace:WaitForChild("Core"):WaitForChild("Data"):WaitForChild("MatchPaused") :: BoolValue

-- Get reference to RefereeEventRemote for pause notifications
local NETWORK_FOLDER = game:GetService("ReplicatedStorage"):WaitForChild("Network") :: Folder
local REFEREE_EVENT_REMOTE = NETWORK_FOLDER:WaitForChild("Referee") :: RemoteEvent

local localPlayer = Players.LocalPlayer

function onBallAdded(ABHBall: SharedTypes.ABHBallInstance)
	local changedOwnershipMaid = Maid.new()
	local jumpMaid = Maid.new()
	local currentPlayerOnBall = ABHBall:WaitForChild("Information"):FindFirstChild("CurrentPlayerOnBall")

	local function handleBallAnimation()
		if not currentPlayerOnBall then
			return
		end

		local ballOwner = currentPlayerOnBall.Value :: Player
		if not ballOwner then return end

		local character = ballOwner.Character :: Model
		if not character then return end

		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		local animator = humanoid:WaitForChild("Animator") :: Animator
		local holdBallAnimationTrack: AnimationTrack?

		local tweenInfo = TweenInfo.new(BOUNCE_COOLDOWN)
		local ballMotor6D = character:WaitForChild("BallOwnership", 5) :: Motor6D
		if not ballMotor6D then return end

		local originalC0 = ballMotor6D.C0

		-- Use a single connection to check for animation state changes instead of a loop
		local function checkAnimationState()
			local animationsTrackPlaying = animator:GetPlayingAnimationTracks()
			local isChargingAnimationPlaying = false

			for _, track: AnimationTrack in animationsTrackPlaying do
				local animationId = track.Animation.AnimationId
				if 
					animationId == ABHAnimations.RHandChargeThrow.AnimationId or 
					animationId == ABHAnimations.LHandChargeThrow.AnimationId or 
					animationId == ABHAnimations.SwitchHands.AnimationId or 
					animationId == ABHAnimations.KeeperAnimation.AnimationId
				then
					isChargingAnimationPlaying = true
					break
				end
			end
			return isChargingAnimationPlaying
		end

		local isBouncing = false
		local function runBounceCycle()
			if isBouncing then return end
			isBouncing = true

			while currentPlayerOnBall.Value == ballOwner and ABHBall:IsDescendantOf(workspace) do
				if checkAnimationState() then
					ballMotor6D.C0 = originalC0
					task.wait(0.1)
					continue
				end

				if not holdBallAnimationTrack or not holdBallAnimationTrack.IsPlaying then
					holdBallAnimationTrack = animator:LoadAnimation(ABHAnimations.HoldBall)
					holdBallAnimationTrack:Play()
				end

				local limit = ABHBall.Size.Y * 1.5
				local bounceToFieldTween = TweenService:Create(ballMotor6D, tweenInfo, {C0 = CFrame.new(originalC0.X, originalC0.Y, limit)})
				bounceToFieldTween:Play()

				-- Check for ownership change during tween wait
				local start = tick()
				while tick() - start < BOUNCE_COOLDOWN and currentPlayerOnBall.Value == ballOwner do
					task.wait(0.05)
				end
				if currentPlayerOnBall.Value ~= ballOwner then break end

				local bounceToHandTween = TweenService:Create(ballMotor6D, tweenInfo, {C0 = originalC0})
				bounceToHandTween:Play()

				start = tick()
				while tick() - start < BOUNCE_COOLDOWN and currentPlayerOnBall.Value == ballOwner do
					task.wait(0.05)
				end
				if currentPlayerOnBall.Value ~= ballOwner then break end
			end
			isBouncing = false

			-- Cleanup when loop exits
			if holdBallAnimationTrack then
				holdBallAnimationTrack:Stop(0.1)
				holdBallAnimationTrack = nil
			end
			if ballMotor6D and character and character.Parent then
				ballMotor6D.C0 = originalC0
			end
		end

		coroutine.wrap(runBounceCycle)()

		jumpMaid:GiveTask(function()
			if holdBallAnimationTrack then 
				holdBallAnimationTrack:Stop(0) 
				holdBallAnimationTrack = nil
			end
			if ballMotor6D and character and character.Parent then
				ballMotor6D.C0 = originalC0
			end
		end)
	end

	if currentPlayerOnBall and currentPlayerOnBall.Value then
		coroutine.wrap(handleBallAnimation)()
	end

	if currentPlayerOnBall then
		changedOwnershipMaid:GiveTask(currentPlayerOnBall:GetPropertyChangedSignal("Value"):Connect(function()
			-- ALWAYS clean up previous animations state when ownership changes (steal or drop)
			jumpMaid:DoCleaning()

			if currentPlayerOnBall.Value then
				-- New owner - start new animation cycle
				coroutine.wrap(handleBallAnimation)()
			end
		end))
	end

	ABHBall.Destroying:Connect(function()
		-- Clean up completely when ball is destroyed
		changedOwnershipMaid:DoCleaning()
		jumpMaid:DoCleaning()
	end)
end

for _, ball in BALLS_FOLDER:GetChildren() do
	coroutine.wrap(onBallAdded)(ball :: SharedTypes.ABHBallInstance)
end
BALLS_FOLDER.ChildAdded:Connect(function(ball)
	coroutine.wrap(onBallAdded)(ball :: SharedTypes.ABHBallInstance)
end)

-- Handle pause notifications from server to stop animations immediately
REFEREE_EVENT_REMOTE.OnClientEvent:Connect(function(data)
	if data and data.action == "BALL_DROPPED_PAUSE" then
		-- Stop all hold ball animations and reset animation state when pause occurs
		local character = localPlayer.Character
		if character then
			local humanoid = character:FindFirstChild("Humanoid")
			if humanoid then
				local animator = humanoid:FindFirstChild("Animator")
				if animator then
					-- Stop ALL animation tracks to reset state completely
					local playingTracks = animator:GetPlayingAnimationTracks()
					for _, track: AnimationTrack in playingTracks do
						if track.Animation then
							local animId = track.Animation.AnimationId
							-- Stop HoldBall animation specifically
							if animId == ABHAnimations.HoldBall.AnimationId then
								track:Stop(0)  -- Stop immediately without fade
								track:Destroy()
							end
						end
					end
				end
			end
		end
	end
end)

return {}
