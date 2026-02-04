--[[
	================================================================================
	MÓDULO: NetworkServer (Servidor de Rede)
	================================================================================
	
	Descrição:
		Módulo central de comunicação servidor-cliente. Processa todas as
		requisições de rede relacionadas ao gameplay:
		- Eventos de bola (spawn, drop, clear)
		- Troca de mãos
		- Arremessos
		- Sistema de goleiro
		- Comandos de árbitro
		- Sistema de tackle
		- Eventos da liga
	
	Autor: Sistema ABH
	Refatorado: Documentação em PT-BR e organização por setores
	================================================================================
]]

--// ============================================================================
--// SETOR: Serviços do Roblox
--// ============================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local RunService = game:GetService("RunService")

--// ============================================================================
--// SETOR: Dependências
--// ============================================================================

local ABHLeague = require("../Implementation/ABHLeague")
local GameStatistics = require("../Systems/GameStatistics")
local ABHBall = require("../Systems/ABHBAll")
local Animations = require(game:GetService("ReplicatedStorage"):WaitForChild("Utilities"):WaitForChild("ABHAnimations"))
local SharedTypes = require(game:GetService("ReplicatedStorage"):WaitForChild("Utilities"):WaitForChild("SharedTypes"))
local SharedAttributes = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Implementation"):WaitForChild("SharedAttributes"))
local Maid = require(game:GetService("ReplicatedStorage"):WaitForChild("Utilities"):WaitForChild("Maid"))
local Janitor = require(game:GetService("ReplicatedStorage"):WaitForChild("Utilities"):WaitForChild("Janitor"))
local Timer = require("../Implementation/Timer")
local Vector = require(game:GetService("ReplicatedStorage"):WaitForChild("Utilities"):WaitForChild("Vector"))
local Utils = require(game:GetService("ReplicatedStorage"):WaitForChild("Utilities"):WaitForChild("Utils"))
local AntiHack = require("../Security/AntiHack")

--// ============================================================================
--// SETOR: Referências do Workspace
--// ============================================================================

local ASSETS_FOLDER = ReplicatedStorage:WaitForChild("Assets") :: Folder
local BALLS_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Balls") :: Folder

--// ============================================================================
--// SETOR: Eventos de Rede
--// ============================================================================

local NETWORK_FOLDER = ReplicatedStorage:WaitForChild("Network") :: Folder
local BALL_EVENTS = NETWORK_FOLDER:FindFirstChild("BallEvents") :: RemoteEvent
local SWITCH_HAND_EVENT = NETWORK_FOLDER:WaitForChild("SwitchHands") :: RemoteEvent
local THROW_EVENT = NETWORK_FOLDER:WaitForChild("ThrowEvent") :: RemoteEvent
local GOALKEEPER_EVENT = NETWORK_FOLDER:WaitForChild("Goalkeeper") :: RemoteEvent
local REFEREE_EVENT = NETWORK_FOLDER:WaitForChild("Referee") :: RemoteEvent
local TACKLING_FUNCTION = NETWORK_FOLDER:WaitForChild("Tackling") :: RemoteFunction
local LEAGUE_EVENT = NETWORK_FOLDER:WaitForChild("LeagueEvent") :: RemoteEvent

--// ============================================================================
--// SETOR: Dados da Partida
--// ============================================================================

local DATA_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Data")
local AWAY_SCORE = DATA_FOLDER:WaitForChild("AwayScore") :: NumberValue
local HOME_SCORE = DATA_FOLDER:WaitForChild("HomeScore") :: NumberValue
local BALL_TIMER = DATA_FOLDER:WaitForChild("BallTimer") :: BoolValue
local HOME_NAME = DATA_FOLDER:WaitForChild("HomeName") :: StringValue
local AWAY_NAME = DATA_FOLDER:WaitForChild("AwayName") :: StringValue
local MATCH_BOOLEAN = DATA_FOLDER:WaitForChild("Match") :: BoolValue
local MATCH_PAUSED = DATA_FOLDER:WaitForChild("MatchPaused") :: BoolValue
local TIMER = DATA_FOLDER:WaitForChild("Timer") :: NumberValue

-- Valores padrào dos nomes
HOME_NAME.Value = "HOME"
AWAY_NAME.Value = "AWAY"

--// ============================================================================
--// SETOR: Estado Global
--// ============================================================================

-- Hitbox do goleiro por jogador
local goalkeeperHitbox = {} :: {[number]: Instance}

-- Animação de goleiro por jogador
local playersAnimTrack = {} :: {[number]: AnimationTrack}

-- Cooldown de tackle por jogador
local tacklingCooldown = {} :: {[number]: boolean}

-- Bola spawneada por jogador (para evitar spam)
local spawnedBall = {} :: {[number]: Instance}

--// ============================================================================
--// SETOR: Handler de Eventos de Bola (BALL_EVENTS)
--// ============================================================================

--[[
	Ações disponíveis:
	- SpawnRequest: Cria uma bola na posição do jogador
	- ClearRequest: Remove todas as bolas do campo
	- DropRequest: Solta a bola que o jogador está segurando
]]
BALL_EVENTS.OnServerEvent:Connect(function(player, action)
	local character = player.Character 
	if not character then
		return
	end

	-- Verifica se jogador tem a ferramenta SpawnTool
	local tool = player.Backpack:FindFirstChild("SpawnTool") or character:FindFirstChild("SpawnTool")
	if not tool then
		return
	end

	if action == "SpawnRequest" then
		-- AntiHack: Rate limiting
		if not AntiHack:CheckRateLimit(player, "SpawnRequest") then
			return
		end

		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not humanoidRootPart then
			return
		end

		-- Remove bola anterior do jogador (evita spam)
		if spawnedBall[player.UserId] then
			spawnedBall[player.UserId]:Destroy()
		end

		-- Cria nova bola
		local spawnPosition = humanoidRootPart.CFrame
		local instance = ABHBall:Create(spawnPosition)
		spawnedBall[player.UserId] = instance

		-- Remove imunidade de árbitro se não for Officials
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

--// ============================================================================
--// SETOR: Handler de Troca de mãos (SWITCH_HAND_EVENT)
--// ============================================================================

SWITCH_HAND_EVENT.OnServerEvent:Connect(function(player)
	-- AntiHack: Rate limiting
	if not AntiHack:CheckRateLimit(player, "SwitchHands") then
		return
	end

	-- Determina nova mão
	local currentHand = player:GetAttribute("CurrentHand")
	local handToSwitch = if currentHand == "R" then "L" else "R"

	player:SetAttribute("CurrentHand", handToSwitch)

	-- Se jogador tem bola, anima e transfere
	local character = player.Character
	if character and character:FindFirstChild("BallOwnership") then
		local animator = character:WaitForChild("Humanoid"):WaitForChild("Animator") :: Animator
		local ballMotor6D = character:FindFirstChild("BallOwnership") :: Motor6D

		-- Reproduz animação de troca
		local animationTrack = animator:LoadAnimation(Animations.SwitchHands)
		animationTrack:Play()
		animationTrack.Stopped:Wait()

		-- Define nova mão como Part0 do Motor6D
		local newHand = if handToSwitch == "R" 
			then character:FindFirstChild("Right Arm") :: BasePart
			else character:FindFirstChild("Left Arm") :: BasePart

		ballMotor6D.Part0 = newHand
	end
end)

--// ============================================================================
--// SETOR: Handler de Arremesso (THROW_EVENT)
--// ============================================================================

THROW_EVENT.OnServerEvent:Connect(function(player, power: number, directionData: SharedTypes.DirectionData)
	-- AntiHack: Rate limiting
	if not AntiHack:CheckRateLimit(player, "ThrowEvent") then
		return
	end

	-- AntiHack: Valida dados de arremesso
	if not AntiHack:ValidateThrow(power, directionData) then
		AntiHack:LogViolation(player, "INVALID_THROW", "Power: " .. tostring(power))
		return
	end

	-- Clamp da força entre 0 e 100
	local fixedPower = math.clamp(power, 0, 100)

	local character = player.Character
	if not character then
		return
	end

	-- Verifica se jogador tem posse da bola
	if not character:FindFirstChild("BallOwnership") then
		return
	end

	-- Obtém referências do Motor6D
	local ballMotor6D = character:FindFirstChild("BallOwnership") :: Motor6D
	local throwingHand = ballMotor6D.Part0 :: BasePart
	local instance = ballMotor6D.Part1 :: SharedTypes.ABHBallInstance
	local startingCFrame = throwingHand.CFrame

	-- Executa arremesso
	ABHBall:Throw(player, instance, directionData, fixedPower)
end)

--// ============================================================================
--// SETOR: Handler de Goleiro (GOALKEEPER_EVENT)
--// ============================================================================

GOALKEEPER_EVENT.OnServerEvent:Connect(function(player, state: boolean)
	-- AntiHack: Rate limiting
	if not AntiHack:CheckRateLimit(player, "Goalkeeper") then
		return
	end

	local existingHitbox = goalkeeperHitbox[player.UserId]

	if state then
		-- Ativa modo goleiro
		if existingHitbox then
			return -- Já está ativo
		end

		local character = player.Character
		if not character then
			return
		end

		local humanoid = character:FindFirstChild("Humanoid") :: Humanoid
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart

		if not humanoid or not humanoidRootPart then
			return
		end

		-- Carrega e reproduz animação de goleiro
		local animator = humanoid:WaitForChild("Animator") :: Animator
		local animationTrack = animator:LoadAnimation(Animations.KeeperAnimation)
		playersAnimTrack[player.UserId] = animationTrack
		animationTrack:Play()

		-- Cria hitbox de detecção
		local hitboxInstance = Instance.new("Part")
		hitboxInstance.Name = "KeeperHitbox"
		hitboxInstance.Size = Vector3.new(8, 8, 5)
		hitboxInstance.Massless = true
		hitboxInstance.CanCollide = false
		hitboxInstance.Transparency = 1
		hitboxInstance.Parent = character

		-- Conecta hitbox ao HumanoidRootPart
		local hitboxWeld = Instance.new("Motor6D")
		hitboxWeld.Name = "KeeperWeld"
		hitboxWeld.Part0 = humanoidRootPart
		hitboxWeld.Part1 = hitboxInstance
		hitboxWeld.C0 = CFrame.new(0, 0, -1.5)
		hitboxWeld.Parent = hitboxInstance

		goalkeeperHitbox[player.UserId] = hitboxInstance

		-- Loop de detecção de bola
		local detectionConnection
		detectionConnection = RunService.Heartbeat:Connect(function()
			if not hitboxInstance or not hitboxInstance.Parent then
				detectionConnection:Disconnect()
				return
			end

			-- AntiHack: Verifica se hitbox foi modificada
			AntiHack:CheckKeeperHitbox(hitboxInstance, player)

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
		-- Desativa modo goleiro
		if existingHitbox then
			existingHitbox:Destroy()
			goalkeeperHitbox[player.UserId] = nil

			-- Restaura velocidade de caminhada
			local character = player.Character
			if character then
				local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
				if humanoid then
					humanoid.WalkSpeed = SharedAttributes:GetWalkSpeed()
				end
			end

			-- Para e limpa animação
			if playersAnimTrack[player.UserId] then
				playersAnimTrack[player.UserId]:Stop()
				playersAnimTrack[player.UserId]:Destroy()
				playersAnimTrack[player.UserId] = nil
			end
		end
	end
end)

--// ============================================================================
--// SETOR: Handler de Árbitro (REFEREE_EVENT)
--// ============================================================================

--[[
	Ações disponíveis para árbitros:
	- ADD_GOAL: Adiciona gol
	- REMOVE_GOAL: Remove gol
	- TOGGLE_BALL_TIMER: Liga/desliga timer da bola
	- TOGGLE_TIMER: Liga/desliga timer da partida
	- BEGIN_LEAGUE: Inicia partida
	- RESET_MATCH: Reseta partida
	- PAUSE_MATCH: Pausa partida
	- RESUME_MATCH: Retoma partida
	- TOGGLE_NAME: Muda nome do time
	- RESET_TIMER: Reseta timer
	- REF_SPAWN_BALL: Spawna bola em posição
	- REF_PENALTY: Marca pênalti
	- REMOVE_BALLS: Remove todas as bolas
]]
REFEREE_EVENT.OnServerEvent:Connect(function(player, data)
	-- Apenas Officials podem usar comandos de árbitro
	if (player.Team :: Team).Name ~= "Officials" then
		return
	end

	local action = data.action

	if action == "ADD_GOAL" then
		if data.isHome then
			HOME_SCORE.Value += 1
		else
			AWAY_SCORE.Value += 1
		end
		if GameStatistics then
			pcall(function() GameStatistics.RecordTeamGoal(data.isHome) end)
		end

	elseif action == "REMOVE_GOAL" then
		if data.isHome then
			HOME_SCORE.Value = math.max(0, HOME_SCORE.Value - 1)
		else
			AWAY_SCORE.Value = math.max(0, AWAY_SCORE.Value - 1)
		end
		if GameStatistics and GameStatistics.DecrementTeamGoal then
			pcall(function() GameStatistics.DecrementTeamGoal(data.isHome) end)
		end

	elseif action == "TOGGLE_BALL_TIMER" then
		BALL_TIMER.Value = not BALL_TIMER.Value

	elseif action == "TOGGLE_TIMER" then
		Timer:Toggle(data.state)

	elseif action == "BEGIN_LEAGUE" then
		ABHLeague:BeginLeague()

	elseif action == "RESET_MATCH" then
		ABHLeague:Reset()

	elseif action == "PAUSE_MATCH" then
		ABHLeague:PauseMatch()

	elseif action == "RESUME_MATCH" then
		ABHLeague:ResumeMatch()

	elseif action == "TOGGLE_NAME" then
		if data.isHome then
			HOME_NAME.Value = data.teamName
			if GameStatistics then 
				pcall(function() GameStatistics.NotifyTeamNameChange(data.teamName, true) end) 
			end
		else
			AWAY_NAME.Value = data.teamName
			if GameStatistics then 
				pcall(function() GameStatistics.NotifyTeamNameChange(data.teamName, false) end) 
			end
		end

	elseif action == "RESET_TIMER" then
		Timer:Reset()

	elseif action == "REF_SPAWN_BALL" then		
		ABHLeague:SpawnFreeThrow(data.position :: Vector3, data.isHome :: boolean)

	elseif action == "REF_PENALTY" then
		ABHLeague:SpawnPenalty(data.isHome :: boolean, data.isHomeGLT :: boolean)

	elseif action == "REMOVE_BALLS" then
		ABHLeague:DoCleaning()
	end
end)

--// ============================================================================
--// SETOR: Handler de Tackle (TACKLING_FUNCTION)
--// ============================================================================

TACKLING_FUNCTION.OnServerInvoke = function(player: Player)
	-- AntiHack: Rate limiting
	if not AntiHack:CheckRateLimit(player, "Tackling") then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	-- não pode tacklear se já tem bola
	if character:FindFirstChild("BallOwnership") then
		return
	end

	local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
	if not humanoid then
		return
	end

	-- Verifica cooldown
	if tacklingCooldown[player.UserId] then
		return
	end

	-- Aplica cooldown
	tacklingCooldown[player.UserId] = true
	task.delay(1, function()
		tacklingCooldown[player.UserId] = nil
	end)

	-- Carrega animação baseada na mão atual
	local animator = humanoid:WaitForChild("Animator") :: Animator
	local currentHand = player:GetAttribute("CurrentHand")
	local animationToLoad = if currentHand == "R" 
		then animator:LoadAnimation(Animations.RHandTackle)
		else animator:LoadAnimation(Animations.LHandTackle)

	-- Determina mão física
	local presumedHand = if currentHand == "R" 
		then character:FindFirstChild("Right Arm") :: BasePart
		else character:FindFirstChild("Left Arm") :: BasePart

	if not presumedHand then
		return
	end

	-- Reproduz animação de tackle
	animationToLoad.Priority = Enum.AnimationPriority.Action4
	animationToLoad:Play()	

	-- Loop de detecção de bola durante tackle
	local tackleActive = true
	task.spawn(function()
		local overlapParams = OverlapParams.new()
		overlapParams.FilterDescendantsInstances = {BALLS_FOLDER, workspace}
		overlapParams.FilterType = Enum.RaycastFilterType.Include

		while tackleActive and character and character.Parent do
			local currentPresumedHand = if currentHand == "R" 
				then character:FindFirstChild("Right Arm") 
				else character:FindFirstChild("Left Arm")
			if not currentPresumedHand then break end

			-- Verifica bolas no raio da mão
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

			-- Verifica bolas em posse de outros jogadores
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

	-- Aguarda fim da animação
	animationToLoad.Stopped:Wait()
	tackleActive = false
	tacklingCooldown[player.UserId] = nil
	return
end

--// ============================================================================
--// SETOR: Handler de Eventos da Liga (LEAGUE_EVENT)
--// ============================================================================

LEAGUE_EVENT.OnServerEvent:Connect(function(player, action, ...)
	if action == "TEAM_FREE_THROW_CLIENT" then
		-- Jogador quer pegar cobrança de falta
		local ballName: string = ...
		local ball = BALLS_FOLDER:FindFirstChild(ballName)
		if not ball then
			return
		end

		local forceField = ball:FindFirstChild("ForceField")
		if not forceField then
			return
		end

		-- Verifica se já foi pega
		if forceField:GetAttribute("Took") == true then
			return
		end

		-- Verifica time do jogador
		local teamName = (player.Team :: Team).Name
		if teamName:find("Substitutes") then
			return
		end

		-- Verifica se jogador é do time correto
		local isHomeThrow = forceField:GetAttribute("isHome")
		if isHomeThrow == true and not teamName:find("Home") then
			return
		end
		if isHomeThrow == false and not teamName:find("Away") then
			return
		end

		-- Teletransporta jogador para a bola
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
		-- Jogador quer trocar de time
		local teamName = ...

		if teamName == "Home" then
			player.Team = Teams["@Home Substitutes"]
		elseif teamName == "Away" then
			player.Team = Teams["@Away Substitutes"]
		end
	end
end)

--// ============================================================================
--// SETOR: Cleanup de Jogador
--// ============================================================================

Players.PlayerRemoving:Connect(function(p)
	tacklingCooldown[p.UserId] = nil
end)

--// ============================================================================
--// SETOR: Retorno do Módulo
--// ============================================================================

return {}
