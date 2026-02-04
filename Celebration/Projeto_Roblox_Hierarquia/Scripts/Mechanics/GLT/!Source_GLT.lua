local Teams = game:GetService("Teams")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Maid = require(ReplicatedStorage:WaitForChild("Utils"):WaitForChild("Maid"))
local BallService = require(ServerScriptService:WaitForChild("Services"):WaitForChild("BallService"))
local SoundModuleService = require(ServerScriptService:WaitForChild("Services"):WaitForChild("SoundModuleService"))

local gltsMaid = {}

local statsFolder: Folder = workspace:WaitForChild("Core"):WaitForChild("Stats")
local statEvent: BindableEvent = ServerScriptService:WaitForChild("ServerRemote"):WaitForChild("StatEvent")

function GetClosestPlayerFromGLT(glt: BasePart)
	local PresumedGK: Player? = Teams["-"..glt.Name.." Goalkeeper"]:GetPlayers()[1]
	if PresumedGK then return PresumedGK end

	local closestPlayer: Player?
	local closestMagnitude: number = math.huge
	for _, player: Player in pairs(Teams[glt.Name]:GetPlayers()) do
		if not player.Character then continue end
		if not player.Character:FindFirstChild("HumanoidRootPart") then continue end
		
		local distance = (player.Character.HumanoidRootPart.Position - glt.Position).Magnitude
		if distance > closestMagnitude then continue end
		closestMagnitude = distance
		closestPlayer = player
	end
	
	return closestPlayer
end

function CalculateGLTDelay(player: Player, ballVelocityMagnitude: number)
	if not player then return 0.15 end
	local playerPing: number = player["leaderstats"]["Ping"].Value
	return math.min((playerPing/500 + ballVelocityMagnitude/750 + .125), 0.5)
end

function HandleGoalDetection(GLT: BasePart)
	gltsMaid[GLT] = {}
	gltsMaid[GLT]["Main"] = Maid.new()
	gltsMaid[GLT]["Saved"] = Maid.new()

	local function GiveTask()
		gltsMaid[GLT]["Main"]:Destroy()
		gltsMaid[GLT]["Saved"]:Destroy()
		
		local saved = false

		gltsMaid[GLT]["Main"]:GiveTask(GLT.Touched:Connect(function(partThatTouched: BasePart)
			local velocity = partThatTouched.AssemblyLinearVelocity.Magnitude
			local ball = BallService:GetBall(partThatTouched)
			if not ball then return end
			if ball.Data.PlayerOnBall.Value ~= nil then return end

			gltsMaid[GLT]["Saved"]:GiveTask(ball.Data.PlayerOnBall:GetPropertyChangedSignal("Value"):Connect(function()
				print("saved")
				-- if ball.Data.PlayerOnBall.Value == nil then return end
				saved = true
				SoundModuleService:Play(SoundService.Crowd.Missed)
				GiveTask()
				return
			end))

			local closestPlayer: Player = GetClosestPlayerFromGLT(GLT)
			local gltDelay = CalculateGLTDelay(closestPlayer, velocity)
			task.wait(gltDelay)
			if saved then return end
			if ball.Data.PlayerOnBall.Value == nil then
				ball.Instance.CanTouch = false
				ball.Instance.Highlight.FillColor = Color3.new(255, 0, 0)
				ball.Instance.Highlight.FillTransparency = 0
				Debris:AddItem(ball.Instance, 3)

				local playerTeam: string = ball.Data.LastShoot.Value.Team.Name
				if playerTeam:find("@") then return end

				if (string.find(playerTeam, "Home") or string.find(playerTeam, "Away")) and playerTeam:sub(1, 1) == "-" then
					-- Removes the "-", " "(empty space) and "Goalkeeper" from playerTeam, if the player team is either -Home Goalkeeper or -Away Goalkeeper
					playerTeam = playerTeam:gsub("^%-%s*(.-)%sGoalkeeper$", "%1")
				end

				local assister: ObjectValue | nil = ball.Data.LastShootShoot.Value
				local ownGoal: boolean = false

				if string.find(ball.Data.LastShoot.Value.Team.Name, "Home") or string.find(ball.Data.LastShoot.Value.Team.Name, "Away") then	
					local processedLastShootTeam = ball.Data.LastShoot.Value.Team.Name:gsub("^%-%s*(.-)%s*Goalkeeper$", "%1")
					local processedLastShootShootTeam = ball.Data.LastShootShoot.Value and ball.Data.LastShootShoot.Value.Team.Name:gsub("^%-%s*(.-)%s*Goalkeeper$", "%1")			

					if processedLastShootTeam ~= processedLastShootShootTeam or ball.Data.LastShoot.Value == ball.Data.LastShootShoot.Value then
						assister = nil
					end
				else
					assister = nil
				end

				statEvent:Fire("Goal", {
					scorer = ball.Data.LastShoot.Value,
					assist = assister,
					team = ball.Data.LastShoot.Value.Team.Name,
					ownGoal = playerTeam == GLT.Name,
					gltName = GLT.Name
				})
			end
			GiveTask()
		end))
	end

	GiveTask()
end

for _, glt: BasePart in pairs(workspace.Core.GoalDetections:GetChildren()) do
	task.spawn(HandleGoalDetection, glt)
end
