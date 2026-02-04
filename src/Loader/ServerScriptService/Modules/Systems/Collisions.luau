local PhysicsService = game:GetService("PhysicsService")
local Teams = game:GetService("Teams")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Janitor = require(game:GetService("ReplicatedStorage"):WaitForChild("Utilities"):WaitForChild("Janitor"))

local MATCH_VALUE = workspace:WaitForChild("Core"):WaitForChild("Data"):WaitForChild("Match") :: BoolValue

local DISPLACEMENT_OFFSET = 5

local BALL_COLLISION = "ABHBall"
local PLAYER_COLLISION = "Player"
local GOALKEEPER_COLLISION = "Goalkeeper"
local AREA_COLLISION = "AreaCollision"
local ANTI_CAMP_COLLISION = "Antiplayer"

PhysicsService:RegisterCollisionGroup(BALL_COLLISION)
PhysicsService:RegisterCollisionGroup(PLAYER_COLLISION)
PhysicsService:RegisterCollisionGroup(GOALKEEPER_COLLISION)
PhysicsService:RegisterCollisionGroup(AREA_COLLISION)
PhysicsService:RegisterCollisionGroup(ANTI_CAMP_COLLISION)

PhysicsService:CollisionGroupSetCollidable(ANTI_CAMP_COLLISION, BALL_COLLISION, false)
PhysicsService:CollisionGroupSetCollidable(BALL_COLLISION, AREA_COLLISION, false)
PhysicsService:CollisionGroupSetCollidable(BALL_COLLISION, PLAYER_COLLISION, false)
PhysicsService:CollisionGroupSetCollidable(BALL_COLLISION, GOALKEEPER_COLLISION, false)
PhysicsService:CollisionGroupSetCollidable(AREA_COLLISION, GOALKEEPER_COLLISION, false)


PhysicsService:CollisionGroupSetCollidable(AREA_COLLISION, PLAYER_COLLISION, MATCH_VALUE.Value)
MATCH_VALUE:GetPropertyChangedSignal("Value"):Connect(function()
	PhysicsService:CollisionGroupSetCollidable(AREA_COLLISION, PLAYER_COLLISION, MATCH_VALUE.Value)
end)

return {}