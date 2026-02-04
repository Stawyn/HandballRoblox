local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local bodyParts = {
	"Head",
	"Left Arm",
	"Right Arm",
	"Left Leg",
	"Right Leg",
	"Torso",
	"HumanoidRootPart"
}

local collisionGroups = {
	"GLT",
	"Ball",
	"Player",
	"AntiCamp"
}

for i, v in pairs(collisionGroups) do
	PhysicsService:RegisterCollisionGroup(v)
end
PhysicsService:CollisionGroupSetCollidable("GLT", "Ball", false)
PhysicsService:CollisionGroupSetCollidable("AntiCamp", "Ball", false)
PhysicsService:CollisionGroupSetCollidable("Ball", "Player", false)

workspace.Core.GoalDetections.Home.CollisionGroup = "GLT"
workspace.Core.GoalDetections.Away.CollisionGroup = "GLT"

for i, v in pairs(workspace.Core.Anticamp:GetChildren()) do
	v.CollisionGroup = "AntiCamp"
end

function onPlayerJoined(player: Player)
	local function onCharacterAdded(character: Model?)
		for i: number = 1, #bodyParts do
			character:WaitForChild(bodyParts[i])
		end
		
		for _, characterPart: BasePart in pairs(character:GetChildren()) do
			if not characterPart:IsA("BasePart") then continue end
			characterPart.CollisionGroup = "Player"
		end
	end
	
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)
end

for _, player: Player in pairs(Players:GetPlayers()) do
	task.spawn(onPlayerJoined, player)
end
Players.PlayerAdded:Connect(onPlayerJoined)
