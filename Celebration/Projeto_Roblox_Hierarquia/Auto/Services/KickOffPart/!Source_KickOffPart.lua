local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ServerScriptService = game:GetService("ServerScriptService")

local BallService = require(ServerScriptService:WaitForChild("Services"):WaitForChild("BallService"))

local HOME_PART = script.Home
local AWAY_PART = script.Away


function handleTouched(part: BasePart)
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
			humanoidRootPart.CFrame += Vector3.new(0, 0, 25)
		elseif teamName:find("Away") and part.BrickColor == BrickColor.new("Really blue") then
			local character = player.Character
			if not character then return end
			local humanoidRootPart: BasePart = character:FindFirstChild("HumanoidRootPart")
			if not humanoidRootPart then return end
			humanoidRootPart.CFrame += Vector3.new(0, 0, -25)
		end
	end)
end

return function ()
	task.spawn(function()
		local homePart = HOME_PART:Clone()
		local awayPart = AWAY_PART:Clone()

		task.spawn(handleTouched, homePart)
		task.spawn(handleTouched, awayPart)

		homePart.Parent = workspace
		awayPart.Parent = workspace

		Debris:AddItem(homePart, 12)
		Debris:AddItem(awayPart, 12)
		task.wait(12)
		BallService:RemoveAllBallsSetPiece()
	end)
end
