type PlayerHoldBalls = {
	[Player]: Maid
}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maid = require(ReplicatedStorage:WaitForChild("Utils"):WaitForChild("Maid"))
local holdballAnimation: Animation = ReplicatedStorage:WaitForChild("Animations"):WaitForChild("HoldBall")
local keeperHoldball: Animation = ReplicatedStorage:WaitForChild("Animations"):WaitForChild("KeeperHoldBall")

local playerHoldballs = {}
local playerKeeperHoldBall = {}

function onPlayerJoined(player: Player)
	playerHoldballs[player] = Maid.new()
	playerKeeperHoldBall[player] = Maid.new()
	
	local function onCharacterAdded(character: Model)
		character:WaitForChild("HumanoidRootPart")
		character:WaitForChild("Humanoid")
		local humanoidRootPart: BasePart, humanoid: Humanoid = character.HumanoidRootPart, character.Humanoid
		
		
		playerHoldballs[player]:Destroy()
		local animationTrack: AnimationTrack | nil = nil
		
		playerHoldballs[player]:GiveTask(humanoidRootPart.ChildAdded:Connect(function(child: Weld)
			if child.Name ~= "BallWeld" then return end
			local animator: Animator = humanoid:FindFirstChildOfClass("Animator")
			local ballInstance = child.Part0
			
			if not ballInstance:GetAttribute("Picked") then
				animationTrack = animator:LoadAnimation(holdballAnimation)
				playerKeeperHoldBall[player]:GiveTask(ballInstance:GetAttributeChangedSignal("Picked"):Connect(function()
					if animationTrack then animationTrack:Stop() end
					if ballInstance:GetAttribute("Picked") then
						animationTrack = animator:LoadAnimation(keeperHoldball)
					else
						animationTrack = animator:LoadAnimation(holdballAnimation)
					end
					animationTrack:Play()
				end))
			else
				animationTrack = animator:LoadAnimation(keeperHoldball)
			end
			animationTrack:Play()
		end))
		playerHoldballs[player]:GiveTask(humanoidRootPart.ChildRemoved:Connect(function(child: Weld)
			if child.Name ~= "BallWeld" then return end
			if not animationTrack then return end
			animationTrack:Stop()
			playerKeeperHoldBall[player]:Destroy()
		end))
	end
	
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)
end

function onPlayerLeave(player: Player)
	if not playerHoldballs[player] then return end
	playerHoldballs[player]:Destroy()
	playerKeeperHoldBall[player]:Destroy()
end

for _, player: Player in pairs(Players:GetPlayers()) do
	task.spawn(onPlayerJoined, player)
end
Players.PlayerAdded:Connect(onPlayerJoined)
Players.PlayerRemoving:Connect(onPlayerLeave)
