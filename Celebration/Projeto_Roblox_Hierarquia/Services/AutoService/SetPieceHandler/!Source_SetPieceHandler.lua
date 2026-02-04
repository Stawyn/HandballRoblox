local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ServerScriptService = game:GetService("ServerScriptService")

local BallService = require(ServerScriptService:WaitForChild("Services"):WaitForChild("BallService"))

local HomeGLT = workspace:WaitForChild("Core"):WaitForChild("GoalDetections"):WaitForChild("Home")
local AwayGLT = HomeGLT.Parent.Away

return function (part: BasePart, desiredPosition: Vector3, existingBall: BasePart): BasePart
	local cooldown = {}

	local function HandleCooldown(player: Player)
		if cooldown[player] then return end
		cooldown[player] = true
		task.wait(.125)
		cooldown[player] = nil
	end

	part.Touched:Connect(function(partThatTouched: BasePart)
		local player = Players:GetPlayerFromCharacter(partThatTouched.Parent)
		if not player then return end
		if player:GetAttribute("SetPiece") == true then return end

		if cooldown[player] then return end
		task.spawn(HandleCooldown, player)

		local teamName = player.Team.Name

		if teamName:find("Home") and part.BrickColor == BrickColor.new("Really red") then
			local character = player.Character
			if not character then return end
			local humanoidRootPart: BasePart = character:FindFirstChild("HumanoidRootPart")
			if not humanoidRootPart then return end
			local positionOffset = (humanoidRootPart.CFrame * CFrame.new(0, 0, 25)).Position
			humanoidRootPart.CFrame = CFrame.new(positionOffset, HomeGLT.Position)
		elseif teamName:find("Away") and part.BrickColor == BrickColor.new("Really blue") then
			local character = player.Character
			if not character then return end
			local humanoidRootPart: BasePart = character:FindFirstChild("HumanoidRootPart")
			if not humanoidRootPart then return end
			local positionOffset = (humanoidRootPart.CFrame * CFrame.new(0, 0, -25)).Position
			humanoidRootPart.CFrame = CFrame.new(positionOffset, AwayGLT.Position)
			-- humanoidRootPart.CFrame += Vector3.new(0, 0, -25)
		end
	end)

	local setPieceSide = part.BrickColor == BrickColor.new("Really blue") and "Home" or "Away"
	
	if not existingBall then
		local positionToSpawn = desiredPosition or Vector3.new(part.Position.X, 4, part.Position.Z)
		local newBall = BallService.new(positionToSpawn, setPieceSide)
		part.Parent = newBall.Instance
		
		task.delay(12, function()
			if newBall then
				newBall:RemoveSetPiece()
			end
		end)
	else
		part.Parent = existingBall
	end
	
	Debris:AddItem(part, 12)
	return part
end
