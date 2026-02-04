--[[
    ================================================================================
    MÓDULO: NetworkServer
    ================================================================================
    Descrição: Processamento central de todos os RemoteEvents do jogo ABH.
               Este módulo atua como hub de comunicação entre cliente e servidor.
    
    Funcionalidades:
        - BALL_EVENTS: Spawn, Clear e Drop de bolas
        - SWITCH_HAND_EVENT: Troca de mão dominante do jogador
        - THROW_EVENT: Processamento de arremessos
        - GOALKEEPER_EVENT: Ativação/desativação de hitbox de defesa
        - REFEREE_EVENT: Ações administrativas do árbitro (gols, timer, etc.)
        - TACKLING_FUNCTION: Lógica de tackle/roubo de bola
        - LEAGUE_EVENT: Eventos de partida (free throw, troca de times)
    
    Dependências:
        - ABHBall: Sistema de física da bola
        - ABHLeague: Lógica de partida
        - GameStatistics: Registro de estatísticas
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: SERVIÇOS E DEPENDÊNCIAS
--// ============================================================================

-- Serviços Roblox
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local RunService = game:GetService("RunService")

-- Módulos do Projeto
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

--// ============================================================================
--// SETOR: REFERÊNCIAS E CONSTANTES
--// ============================================================================

-- Pastas do Workspace
local ASSETS_FOLDER = ReplicatedStorage:WaitForChild("Assets") :: Folder
local BALLS_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Balls") :: Folder

-- Eventos de Rede
local NETWORK_FOLDER = ReplicatedStorage:WaitForChild("Network") :: Folder
local BALL_EVENTS = NETWORK_FOLDER:FindFirstChild("BallEvents") :: RemoteEvent
local SWITCH_HAND_EVENT = NETWORK_FOLDER:WaitForChild("SwitchHands") :: RemoteEvent
local THROW_EVENT = NETWORK_FOLDER:WaitForChild("ThrowEvent") :: RemoteEvent
local GOALKEEPER_EVENT = NETWORK_FOLDER:WaitForChild("Goalkeeper") :: RemoteEvent
local REFEREE_EVENT = NETWORK_FOLDER:WaitForChild("Referee") :: RemoteEvent
local TACKLING_FUNCTION = NETWORK_FOLDER:WaitForChild("Tackling") :: RemoteFunction
local LEAGUE_EVENT = NETWORK_FOLDER:WaitForChild("LeagueEvent") :: RemoteEvent

-- Dados da Partida
local DATA_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Data")
local AWAY_SCORE = DATA_FOLDER:WaitForChild("AwayScore") :: NumberValue
local HOME_SCORE = DATA_FOLDER:WaitForChild("HomeScore") :: NumberValue
local BALL_TIMER = DATA_FOLDER:WaitForChild("BallTimer") :: BoolValue
local HOME_NAME = DATA_FOLDER:WaitForChild("HomeName") :: StringValue
local AWAY_NAME = DATA_FOLDER:WaitForChild("AwayName") :: StringValue
local MATCH_BOOLEAN = DATA_FOLDER:WaitForChild("Match") :: BoolValue
local MATCH_PAUSED = DATA_FOLDER:WaitForChild("MatchPaused") :: BoolValue
local TIMER = DATA_FOLDER:WaitForChild("Timer") :: NumberValue

-- Valores iniciais
HOME_NAME.Value = "HOME"
AWAY_NAME.Value = "AWAY"

--// ============================================================================
--// SETOR: ESTADO INTERNO
--// ============================================================================

local goalkeeperHitbox = {} :: {[number]: Instance}    -- Hitboxes de goleiros ativos
local playersAnimTrack = {} :: {[number]: AnimationTrack}  -- Animações de goleiros
local tacklingCooldown = {} :: {[number]: boolean}     -- Cooldown de tackle
local spawnedBall = {} :: {[number]: Instance}         -- Bolas spawnadas por jogador
local spawnCooldown = {} :: {[number]: boolean}         -- Cooldown de spawn (Alto #6)

--// ============================================================================
--// SETOR: HANDLERS DE EVENTOS - BOLA
--// ============================================================================

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
		-- Alto #6: Rate limit de spawn de bolas
		if spawnCooldown[player.UserId] then
			return
		end
		spawnCooldown[player.UserId] = true
		
		-- Cooldown de 5s global para spawn (evita flood spawn/destroy)
		task.delay(5, function()
			spawnCooldown[player.UserId] = nil
		end)
		
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
		-- Anti-Spam Drop (1s cooldown)
		if player:GetAttribute("DropCooldown") then return end
		player:SetAttribute("DropCooldown", true)
		task.delay(1, function() player:SetAttribute("DropCooldown", nil) end)

		if character:FindFirstChild("BallOwnership") then
			-- Bug #6/14: Reposicionar bola antes de soltar (evitar void)
			local motor = character:FindFirstChild("BallOwnership")
			if motor and motor:IsA("Motor6D") and motor.Part1 then
				local ball = motor.Part1
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if hrp and ball:IsA("BasePart") then
					ball.Position = hrp.Position + Vector3.new(0, 3, 0)
					ball.AssemblyLinearVelocity = Vector3.zero
				end
			end
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
	
	-- Validação de Segurança: directionData (evitar NaN/Infinity/Crash)
	if typeof(directionData) ~= "table" then return end
	if typeof(directionData.mouseDirection) ~= "Vector3" then return end
	if directionData.mouseDirection.Magnitude > 1000 or directionData.mouseDirection.Magnitude ~= directionData.mouseDirection.Magnitude then -- Check NaN
		warn("[AntiHack] Invalid throw direction from:", player.Name)
		return
	end

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
	-- Crítico #2: VALIDAR SE É GOLEIRO (Comparação Exata)
	local validGKTeams = {["-Home Goalkeeper"] = true, ["-Away Goalkeeper"] = true}
	local teamName = player.Team and player.Team.Name or ""
	
	-- Permite Lobby usar GK tool quando não há partida ativa
	local isLobbyAllowed = teamName == "Lobby" and MATCH_BOOLEAN.Value == false
	
	if not validGKTeams[teamName] and not isLobbyAllowed then
		warn("[AntiHack] Non-GK tried save:", player.Name)
		return
	end
	
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

		hitboxWeld.Parent = hitboxInstance

		-- Fix Memory Leak #C3: Usar Janitor para gerenciar conexão heartbeat e limpeza
		local hitboxJanitor = Janitor.new()
		hitboxJanitor:Add(hitboxInstance)
		
		hitboxJanitor:Add(RunService.Heartbeat:Connect(function()
			if not hitboxInstance or not hitboxInstance.Parent then
				hitboxJanitor:Cleanup()
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
		end), "Disconnect")
		
		goalkeeperHitbox[player.UserId] = {instance = hitboxInstance, janitor = hitboxJanitor}
	else

		if existingHitbox then
			-- Cleanup correto usando Janitor armazenado
			if existingHitbox.janitor then
				existingHitbox.janitor:Cleanup()
			elseif existingHitbox.instance then -- Fallback legacy
				existingHitbox.instance:Destroy()
			end
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
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp then
		return
	end
	
	-- Segurança C2: Validar distância para Tackle (Anti-Teleport Exploit)
	local nearestBall = nil
	local minDist = math.huge
	
	for _, ball in BALLS_FOLDER:GetChildren() do
		if ball:IsA("BasePart") then
			local d = (ball.Position - hrp.Position).Magnitude
			if d < minDist then
				minDist = d
				nearestBall = ball
			end
		end
	end
	
	-- Se tackle for invocado sem bola perto (max 12 studs), ignorar
	if minDist > 12 then
		return
	end

	if tacklingCooldown[player.UserId] then
		return
	end

	tacklingCooldown[player.UserId] = true
	-- Alto #5: Aumentado cooldown de tackle de 1s para 2s
	task.delay(2, function()
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

		-- Crítico #3: Validar distância (anti-teleport hack)
		local distance = (humanoidRootPart.Position - ball.Position).Magnitude
		if distance > 100 then
			warn("[AntiHack] Teleport attempt:", player.Name, distance)
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






