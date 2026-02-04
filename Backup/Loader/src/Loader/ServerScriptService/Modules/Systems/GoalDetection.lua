local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Maid = require("../../../ReplicatedStorage/Utilities/Maid")
local SharedTypes = require("../../../ReplicatedStorage/Utilities/SharedTypes")
local Vector = require("../../../ReplicatedStorage/Utilities/Vector")
local ABHBallModule = require("./ABHBAll")
--Raposa adicionou
local GameStatistics = require("./GameStatistics")
--Fim Raposa
local ABHLeague = require("../Implementation/ABHLeague")

local BALLS_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Balls") :: Folder
local DATA_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Data") :: Folder
local GLT_FOLDER = workspace:WaitForChild("Core"):WaitForChild("GLT") :: Folder
local HOME_GLT = GLT_FOLDER:WaitForChild("Home") :: BasePart
local AWAY_GLT = GLT_FOLDER:WaitForChild("Away") :: BasePart

local MAXIMUM_GLT_DELAY = 0.45
local MINIMUM_GLT_DELAY = 0.2
local ADDITIONAL_DELAY = 0.125

local GLT_DELAY = 0.275

local function showGoalEmoji(player: Player)
	local character = player.Character
	if not character then return end
	local head = character:FindFirstChild("Head")
	if not head then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "GoalEmoji"
	billboard.Size = UDim2.new(2.5, 0, 2.5, 0)
	billboard.Adornee = head
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = true

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(0, 0, 0, 0) -- Inicia pequeno
	label.Position = UDim2.new(0.5, 0, 0.5, 0)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Text = "⚽"
	label.TextScaled = true
	label.Parent = billboard

	billboard.Parent = head

	-- Tween para aparecer e crescer
	local showTween = TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(1, 0, 1, 0)
	})
	showTween:Play()

	-- Flutuar para cima gradualmente
	local floatTween = TweenService:Create(billboard, TweenInfo.new(5, Enum.EasingStyle.Linear), {
		StudsOffset = Vector3.new(0, 4.5, 0)
	})
	floatTween:Play()

	-- Sumir após 4 segundos (total de 5s contando o fade)
	task.delay(4, function()
		if not label or not billboard then return end
		local fadeTween = TweenService:Create(label, TweenInfo.new(1), {
			TextTransparency = 1
		})
		fadeTween:Play()
		fadeTween.Completed:Connect(function()
			billboard:Destroy()
		end)
	end)
end

function handleGLT(GLT: BasePart)
	local mainConnection = Maid.new()
	local savedConnection = Maid.new()

	local function CleanConnections()
		mainConnection:DoCleaning()
		savedConnection:DoCleaning()
	end

	local function CreateGLTConnections()
		CleanConnections()

		local saved = false
		mainConnection:GiveTask(GLT.Touched:Connect(function(otherPart)
			if not otherPart:IsDescendantOf(BALLS_FOLDER) then
				return
			end

			local ABHBall = otherPart :: SharedTypes.ABHBallInstance
			local currentPlayer = ABHBall.Information.CurrentPlayerOnBall
			if currentPlayer.Value then
				return
			end

			local velocityVector = Vector:Vector3ToVectorLib(ABHBall.AssemblyLinearVelocity)
			local velocity = vector.magnitude(velocityVector)

			savedConnection:GiveTask(currentPlayer:GetPropertyChangedSignal("Value"):Connect(function()
				saved = true
				CreateGLTConnections()
				return
			end))

			task.wait(GLT_DELAY)
			if saved then 
				return
			end
			if currentPlayer.Value then
				return
			end
			if not ABHBall:IsDescendantOf(BALLS_FOLDER) then
				return
			end
			if ABHBallModule:GetGLTCooldown(ABHBall) then
				return
			end
			ABHBallModule:SetGLTCooldown(ABHBall, true)


			--Raposa adicionou
			local scorer = ABHBall.Information.LastThrow.Value :: Player?
			local previousThrower = ABHBall.Information.LastLastThrow.Value :: Player?
			if scorer then
				-- Prevent own goals: if scorer's side corresponds to the GLT side, treat as blocked own goal
				local scorerTeamName = (scorer.Team and scorer.Team.Name) or ""
				local gltName = GLT.Name
				if (scorerTeamName:find("Home") and gltName == "Home") or (scorerTeamName:find("Away") and gltName == "Away") then
					print("[GoalDetection] Own goal prevented for "..scorer.Name.." into "..gltName.." GLT")
					-- Clean up ball like a non-scoring touch (remove/disable) to avoid multiple triggers
					ABHBall.CanTouch = false
					ABHBall.Anchored = true
					if ABHBall:FindFirstChild("Timer") then ABHBall.Timer:Destroy() end
					if ABHBall:FindFirstChild("SpecialMesh") then ABHBall.SpecialMesh:Destroy() end
					ABHBall.TextureID = ""
					ABHBall.Color = BrickColor.Green().Color
					ABHBall.Material = Enum.Material.Neon
					ABHBall.Transparency = 0
					Debris:AddItem(ABHBall, 3)
					-- Recreate connections and return without recording goal
					CreateGLTConnections()
					return
				end
				-- Strict Fast Break: Enemy GK -> Scorer -> Goal
				-- Determine fast break before recording goal so we don't double-count
				local isFastBreak = false
				if previousThrower then
					local scorerTeam = scorer.Team
					local prevTeam = previousThrower.Team

					-- Check if previous thrower was an Enemy Goalkeeper
					local isEnemyGK = false
					if scorerTeam.Name:find("Home") then
						if prevTeam.Name == "-Away Goalkeeper" then isEnemyGK = true end
					elseif scorerTeam.Name:find("Away") then
						if prevTeam.Name == "-Home Goalkeeper" then isEnemyGK = true end
					end

					if isEnemyGK then
						isFastBreak = true
					end
				end

				-- Record event according to whether it was a fast break
				if isFastBreak then
					GameStatistics.RecordEvent(scorer, "FastBreak")
					showGoalEmoji(scorer)
				else
					GameStatistics.RecordEvent(scorer, "Goal")
					showGoalEmoji(scorer)
					-- Count the goal as a Shot On Goal as well (so SOG/Shots are tracked and efficiency can be computed)
					GameStatistics.RecordEvent(scorer, "SOG")
				end

				-- Strict Assist: Must be same team
				if previousThrower and previousThrower ~= scorer and not isFastBreak then
					local scorerTeam = scorer.Team
					local prevTeam = previousThrower.Team

					-- Normalize team check (Home/HomeGK are same "side", but usually assist is from teammate)
					-- Assuming "Home Team" and "-Home Goalkeeper" are teammates.
					local sSide = if scorerTeam.Name:find("Home") then "Home" else "Away"
					local pSide = if prevTeam.Name:find("Home") then "Home" else "Away"

					if sSide == pSide then
						GameStatistics.RecordEvent(previousThrower, "Assist")
						-- Also GK Assist check?
						if prevTeam.Name:find("Goalkeeper") then
							GameStatistics.RecordEvent(previousThrower, "GKAssist")
						end
					end
				end
				-- Determine goalkeeper for conceded goal
				local scoringTeam = scorer.Team
				local defendingGKTeam = nil
				local Teams = game:GetService("Teams")
				if scoringTeam.Name == "Home Team" then
					defendingGKTeam = Teams:FindFirstChild("-Away Goalkeeper")
				elseif scoringTeam.Name == "Away Team" then
					defendingGKTeam = Teams:FindFirstChild("-Home Goalkeeper")
				end

				if defendingGKTeam then
					for _, gk in pairs(defendingGKTeam:GetPlayers()) do
						GameStatistics.RecordEvent(gk, "GoalConceded")
					end
				end
			end
			--Fim Raposa

			ABHBall.CanTouch = false
			ABHBall.Anchored = true
			CleanConnections()
			ABHBall.Timer:Destroy()
			ABHBall.SpecialMesh:Destroy()
			ABHBall.TextureID = ""
			ABHBall.Color = BrickColor.Green().Color
			ABHBall.Material = Enum.Material.Neon
			ABHBall.Transparency = 0
			Debris:AddItem(ABHBall, 3)


			-- Assuming the GLT is properly named...
			local oppositeName = if GLT.Name == "Home" then "Away" else "Home"
			local scoreNumberValue = DATA_FOLDER:FindFirstChild(("%sScore"):format(oppositeName)) :: NumberValue
			scoreNumberValue.Value += 1

			task.delay(2, function()
				ABHLeague:GoalScored(oppositeName)
			end)

			CreateGLTConnections()
		end))
	end

	CreateGLTConnections()
end

task.spawn(handleGLT, HOME_GLT)
task.spawn(handleGLT, AWAY_GLT)

return {}

