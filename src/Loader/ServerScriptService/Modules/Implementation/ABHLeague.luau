--[[
	================================================================================
	MÓDULO: ABHLeague (Sistema de Liga/Partida)
	================================================================================
	
	Descrição:
		Módulo central que gerencia toda a lógica de partidas oficiais:
		- Início, pausa e fim de partidas
		- Controle de tempos (1º e 2º tempo)
		- Cobranças de falta e pênalti
		- Detecção de bola fora
		- Sistema de violações e cartões
		- Spawn de bola após gol
		- Watchdog de segurança (respawn automático)
	
	Setores:
		- SERVIÇOS: Importações do Roblox
		- DADOS: Referências de valores da partida
		- ESTADO: Estado global da liga
		- CONSTANTES: Posições e tempos fixos
		- AUXILIARES: Funções de suporte
		- PARTIDA: BeginLeague, PauseMatch, ResumeMatch, Reset
		- COBRANÇAS: SpawnFreeThrow, SpawnPenalty, ThrowOff
		- DETECção: handleOut, detectSideOut, detectGoalsOut
	
	Autor: Sistema ABH
	Refatorado: Documentação em PT-BR
	================================================================================
]]

--// ============================================================================
--// SETOR: Serviços do Roblox
--// ============================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local RunService = game:GetService("RunService")

--// ============================================================================
--// SETOR: Dados da Partida
--// ============================================================================

local DATA_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Data")

-- Ensure all DATA values exist for system synchronization
local function ensureDataValue(name, className, defaultValue)
	local val = DATA_FOLDER:FindFirstChild(name)
	if not val then
		val = Instance.new(className)
		val.Name = name
		val.Value = defaultValue
		val.Parent = DATA_FOLDER
	end
	return val
end

local HALF = ensureDataValue("Half", "NumberValue", 0)
local MATCH_PAUSED = ensureDataValue("MatchPaused", "BoolValue", false)
ensureDataValue("AwayScore", "NumberValue", 0)
ensureDataValue("HomeScore", "NumberValue", 0)
local BALL_TIMER = ensureDataValue("BallTimer", "BoolValue", false)
ensureDataValue("HomeName", "StringValue", "HOME")
ensureDataValue("AwayName", "StringValue", "AWAY")
ensureDataValue("Match", "BoolValue", false)
ensureDataValue("Timer", "NumberValue", 0)
ensureDataValue("AddedTime", "NumberValue", 0)
ensureDataValue("LastAttack", "BoolValue", false)

--// ============================================================================
--// SETOR: Definição do Módulo e Estado Global
--// ============================================================================

local ABHLeague = {
	HomeTeamManagerUserId = 0,   -- ID do manager do time Home
	AwayTeamManagerUserId = 0,   -- ID do manager do time Away
	CurrentHalf = -1,            -- Tempo atual (-1=não iniciado, 1=1º tempo, 2=2º tempo)
	BeingPlayed = false,         -- Se a partida está em andamento
	lastGlobalThrower = nil,     -- Último jogador que arremessou (para watchdog)
	StopWatchdogUntil = 0        -- Timestamp para pausar watchdog (após limpeza manual)
}

--// ============================================================================
--// SETOR: Dependências
--// ============================================================================

local GameStatistics = require("../Systems/GameStatistics") -- Raposa: Sistema de estatísticas
local ABHBall = require("../Systems/ABHBAll")
local CardSystem = require(ReplicatedStorage.Modules.Systems.CardSystem)
local Janitor = require(game:GetService("ReplicatedStorage"):WaitForChild("Utilities"):WaitForChild("Janitor"))
local SharedTypes = require(game:GetService("ReplicatedStorage"):WaitForChild("Utilities"):WaitForChild("SharedTypes"))
local Vector = require(game:GetService("ReplicatedStorage"):WaitForChild("Utilities"):WaitForChild("Vector"))
local Utils = require(game:GetService("ReplicatedStorage"):WaitForChild("Utilities"):WaitForChild("Utils"))
local ServerEvents = require("./ServerEvents")
local Maid = require(game:GetService("ReplicatedStorage"):WaitForChild("Utilities"):WaitForChild("Maid"))

-- Raposa: Registrar ultimo jogador que jogou a bola
ServerEvents.League:Connect(function(action, player)
	if action == "PLAYER_THROW" then
		ABHLeague.lastGlobalThrower = player
	end
end)

local BALLS_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Balls") :: Folder
local NETWORK_FOLDER = ReplicatedStorage:WaitForChild("Network") :: Folder
local LEAGUE_EVENT = NETWORK_FOLDER:WaitForChild("LeagueEvent") :: RemoteEvent
local REFEREE_EVENT = NETWORK_FOLDER:WaitForChild("Referee") :: RemoteEvent
local OUT_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Out") :: Folder
local REAL_FIELD = workspace:WaitForChild("Core"):WaitForChild("Field"):WaitForChild("RealField")
local ANTI_INVADE = ReplicatedStorage:WaitForChild("Anti-Invade")

-- CONFIGURAàƒÆ’à¢â‚¬Â¡àƒÆ’à¢â‚¬Â¢ES DE TEMPO PARA TESTES
local TEST_MODE = false -- Mude para true se quiser usar os tempos de teste abaixo
local HALF_TIME_COUNTDOWN = if TEST_MODE then 15 else 30
local FULL_TIME_WAIT = if TEST_MODE then 15 else 120
-- FIM CONFIGURAàƒÆ’à¢â‚¬Â¡àƒÆ’à¢â‚¬Â¢ES

local function RunAdminCountdown(duration: number)
	local _K = shared._K_INTERFACE
	if _K and _K.Remote and _K.Remote.StartCountdown then
		_K.Remote.StartCountdown:FireAllClients(workspace:GetServerTimeNow(), duration)
	end
end

local function LockPlayerToForceField(player: Player, forceField: BasePart)
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then return end

	-- Raposa: Anular velocidade instantaneamente ao entrar no ForceField
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero

	task.spawn(function()
		-- Aguarda o jogador pegar a bola de fato
		character:WaitForChild("BallOwnership", 10)
		if not forceField:IsDescendantOf(workspace) then return end

		local lockJanitor = Janitor.new()

		-- Reseta velocidade imediata do HRP
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero

		-- Trava movimento com LinearVelocity
		local lv = Instance.new("LinearVelocity")
		lv.Name = "ForceFieldLock"
		lv.Attachment0 = hrp:FindFirstChild("RootAttachment") or Instance.new("Attachment", hrp)
		lv.MaxForce = math.huge
		lv.VectorVelocity = Vector3.zero
		lv.Parent = hrp
		lockJanitor:Add(lv)

		-- Desabilita pulo
		local oldJumpPower = humanoid.JumpPower
		local oldJumpHeight = humanoid.JumpHeight
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0

		lockJanitor:Add(function()
			if humanoid and humanoid.Parent then
				humanoid.JumpPower = oldJumpPower
				humanoid.JumpHeight = oldJumpHeight
			end
		end)

		-- Limpa tudo quando o forcefield sumir (bola lançada ou tempo acabou)
		lockJanitor:LinkToInstance(forceField)
	end)
end

--// ============================================================================
--// SETOR: Assets e Constantes de Posição
--// ============================================================================

local HOME_PENALTY_FC = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Penalty"):WaitForChild("Home") :: BasePart
local AWAY_PENALTY_FC = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Penalty"):WaitForChild("Away") :: BasePart
local HOME_AREA = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("HomeArea") :: BasePart
local AWAY_AREA = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("AwayArea") :: BasePart

local BOUNDARY_POS = REAL_FIELD.Position
local BOUNDARY_SIZE = REAL_FIELD.Size
local BOUNDARY_MIN = BOUNDARY_POS - BOUNDARY_SIZE / 2
local BOUNDARY_MAX = BOUNDARY_POS + BOUNDARY_SIZE / 2

local DISPLACEMENT_OFFSET = 4
local THROW_TIMER_LIMIT = 15
local PENALTY_TIMER_LIMIT = 15
local START_TIMER = 5

local OUT_DELAY = 0.175

local LEFT_Z = -103
local RIGHT_Z = 103

-- These are positions RELATIVE from facing the teams's goal at front. Not in world position
local RIGHT_AWAY_CT = Vector3.new(147, 2, -103)
local LEFT_AWAY_CT = Vector3.new(147, 2, 103)
local RIGHT_HOME_CT = Vector3.new(-147, 2, 103)
local LEFT_HOME_CT = Vector3.new(-147, 2, -103)

local HOME_GK_POS = Vector3.new(-126, 15, 0)
local AWAY_GK_POS = Vector3.new(126, 15, 0)
local AWAY_PT_POS = Vector3.new(82, 10, 0)
local HOME_PT_POS = Vector3.new(-82, 10, 0)

local MIDDLE_POSITION = Vector3.new(0, 4, 0)
local THROW_MIDDLE_VELOCITY = Vector3.new(0, 60, 0)

local HOME_POS = Vector3.new(-40, 10, 0)
local AWAY_POS = Vector3.new(40, 10, 0)

local lastAttackJanitor = Janitor.new()
local penaltyCooldown = false
local lastGlobalThrower = nil

local ballTimeViolations = {}
local violationCooldowns = {}

function ABHLeague:IssueBallTimeViolation(player: Player)
	local now = tick()
	if violationCooldowns[player.UserId] and now - violationCooldowns[player.UserId] < 5 then
		return
	end
	violationCooldowns[player.UserId] = now

	ballTimeViolations[player.UserId] = (ballTimeViolations[player.UserId] or 0) + 1
	local count = ballTimeViolations[player.UserId]

	if count == 2 then
		-- LEAGUE_EVENT:FireAllClients("BALL_TIME_VIOLATION", player.Name, "CartàƒÆ’à‚Â£o Amarelo!")
		CardSystem:GiveYellow(player)
	elseif count >= 4 then
		-- LEAGUE_EVENT:FireAllClients("BALL_TIME_VIOLATION", player.Name, "CartàƒÆ’à‚Â£o Vermelho!")

		-- Dropar a bola se estiver segurando
		if player.Character then
			local ownership = player.Character:FindFirstChild("BallOwnership")
			if ownership then
				ownership:Destroy()
				pcall(function()
					REFEREE_EVENT:FireClient(player, {action = "BALL_DROPPED_PAUSE"})
				end)
			end

			-- Teletransportar para o spawn apàƒÆ’à†'àƒâ€šà‚Â³s a troca de time
			task.spawn(function()
				task.wait(0.5) -- Espera o motor do Roblox processar a troca de time se necessàƒÆ’à†'àƒâ€šà‚Â¡rio
				pcall(function()
					local crowdSpawn = workspace:FindFirstChild("CrowdSpawn")
					if crowdSpawn and crowdSpawn:FindFirstChild("SpawnLocation") then
						player.Character:PivotTo(crowdSpawn.SpawnLocation.CFrame + Vector3.new(0, 5, 0))
					end
				end)
			end)
		end

		-- Limpar estado da bola no servidor
		for _, ball in ipairs(BALLS_FOLDER:GetChildren()) do
			local info = ball:FindFirstChild("Information")
			if info and info:FindFirstChild("CurrentPlayerOnBall") and info.CurrentPlayerOnBall.Value == player then
				info.CurrentPlayerOnBall.Value = nil
				if ball:IsA("BasePart") then
					ball.AssemblyLinearVelocity = Vector3.zero
					ball.AssemblyAngularVelocity = Vector3.zero
					pcall(function() ball:SetNetworkOwner(nil) end)
				end
			end
		end

		CardSystem:GiveRed(player)
	end
end

function ABHLeague:GetHomeTeamManagerUserId()
	return ABHLeague.HomeTeamManagerUserId
end

function ABHLeague:GetAwayTeamManagerUserId()
	return ABHLeague.AwayTeamManagerUserId
end

function ABHLeague:SetHomeTeamManagerUserId(userId: number)
	local oldManager = Players:GetPlayerByUserId(ABHLeague.HomeTeamManagerUserId)
	if oldManager then
		LEAGUE_EVENT:FireClient(oldManager, "REMOVED_MANAGER")
	end

	ABHLeague.HomeTeamManagerUserId = userId
	local newManager = Players:GetPlayerByUserId(userId)
	if newManager then
		LEAGUE_EVENT:FireClient(newManager, "CHOOSEN_MANAGER")
	end
end

function ABHLeague:SetAwayTeamManagerUserId(userId: number)
	local oldManager = Players:GetPlayerByUserId(ABHLeague.AwayTeamManagerUserId)
	if oldManager then
		LEAGUE_EVENT:FireClient(oldManager, "REMOVED_MANAGER")
	end

	ABHLeague.AwayTeamManagerUserId = userId
	local newManager = Players:GetPlayerByUserId(userId)
	if newManager then
		LEAGUE_EVENT:FireClient(newManager, "CHOOSEN_MANAGER")
	end
end

function ABHLeague:DoCleaning()
	ABHLeague.StopWatchdogUntil = tick() + 10 -- Bloqueia watchdog por 10 segundos
	ABHBall:DoCleaning()
end

function ABHLeague:SetMatchState(state: boolean)
	ABHLeague.BeingPlayed = state
	DATA_FOLDER.Match.Value = state

	if state then
		ANTI_INVADE.Parent = workspace

		-- Raposa: Watchdog para garantir que o jogo nunca fique sem bolas
		task.spawn(function()
			while ABHLeague.BeingPlayed do
				task.wait(5)
				-- Raposa: NàƒÂ£o respawnar se as bolas foram limpas manualmente recentemente (cooldown de 10s)
				if ABHLeague.StopWatchdogUntil and tick() < ABHLeague.StopWatchdogUntil then
					continue
				end

				if #BALLS_FOLDER:GetChildren() == 0 and not MATCH_PAUSED.Value then
					if ABHLeague.lastGlobalThrower and ABHLeague.lastGlobalThrower.Parent then
						-- Spawn na posicao do ultimo jogador
						local character = ABHLeague.lastGlobalThrower.Character
						if character and character:FindFirstChild("HumanoidRootPart") then
							local ball = ABHBall:Create(character.HumanoidRootPart.CFrame + Vector3.new(0, 5, 0), ABHLeague.lastGlobalThrower)
							if ball:FindFirstChild("ForceField") then
								ball.ForceField:Destroy() -- Garantir que pode ser pega
							end
						else
							ABHLeague:ThrowOff()
						end
					else
						ABHLeague:ThrowOff()
					end
				end
			end
		end)

		-- Raposa: Remover SpawnTool e KeeperTool de quem estiver no Lobby ao comeàƒÂ§ar o jogo
		for _, player in ipairs(Players:GetPlayers()) do
			if player.Team and player.Team.Name == "Lobby" then
				for _, toolName in {"SpawnTool", "KeeperTool"} do
					local t = player.Backpack:FindFirstChild(toolName)
					if t then
						t:Destroy()
					end
					if player.Character then
						local tc = player.Character:FindFirstChild(toolName)
						if tc then
							tc:Destroy()
						end
					end
				end
			end
		end
	else
		ANTI_INVADE.Parent = ReplicatedStorage

		-- Raposa: Dar SpawnTool e KeeperTool de volta para quem estiver no Lobby ao finalizar o jogo
		for _, player in ipairs(Players:GetPlayers()) do
			if player.Team and player.Team.Name == "Lobby" then
				local SPAWN_TOOL = ServerStorage:FindFirstChild("SpawnTool")
				if SPAWN_TOOL then
					local spawnTool = SPAWN_TOOL:Clone()
					spawnTool.Parent = player.Backpack
				end

				local KEEPER_TOOL = ServerStorage:FindFirstChild("KeeperTool")
				if KEEPER_TOOL then
					local keeperTool = KEEPER_TOOL:Clone()
					keeperTool.Parent = player.Backpack
				end
			end
		end
	end
end

function ABHLeague:PauseMatch()
	if not ABHLeague.BeingPlayed then return end
	local Timer = require("./Timer")
	MATCH_PAUSED.Value = true
	Timer:Toggle(false)
	if GameStatistics then
		pcall(function() GameStatistics.PauseMatch() end)
	end

	-- Notify all players holding balls BEFORE destroying ownership
	for _, player in Players:GetPlayers() do
		if player.Character then
			local ownership = player.Character:FindFirstChild("BallOwnership")
			if ownership then
				pcall(function()
					REFEREE_EVENT:FireClient(player, {action = "BALL_DROPPED_PAUSE"})
				end)
			end
		end
	end

	-- Anchor and disable interactivity for all balls
	for _, ball in ipairs(BALLS_FOLDER:GetChildren()) do
		if not ball or not ball:IsDescendantOf(BALLS_FOLDER) then continue end

		if ball:IsA("BasePart") or ball:IsA("MeshPart") or ball:FindFirstChild("Information") then
			-- Force ball drop if someone is holding it
			local info = ball:FindFirstChild("Information")
			if info and info:FindFirstChild("CurrentPlayerOnBall") then
				local player = info.CurrentPlayerOnBall.Value
				if player and player.Character then
					local ownership = player.Character:FindFirstChild("BallOwnership")
					if ownership then
						ownership:Destroy()
					end
				end
				info.CurrentPlayerOnBall.Value = nil
			end

			-- Reset physics and take ownership to server for instant reaction
			if ball:IsA("BasePart") then
				ball.AssemblyLinearVelocity = Vector3.zero
				ball.AssemblyAngularVelocity = Vector3.zero
				pcall(function() ball:SetNetworkOwner(nil) end)
			end

			-- PAUSE: Anchor ball and disable collision
			ball.Anchored = true
			pcall(function() ball.CanCollide = false end)
			pcall(function() ball.CanTouch = false end)
			ball:SetAttribute("Paused", true)
		end
	end
end

function ABHLeague:ResumeMatch()
	if not ABHLeague.BeingPlayed then return end
	local Timer = require("./Timer")
	MATCH_PAUSED.Value = false
	Timer:Toggle(true)
	BALL_TIMER.Value = true
	if GameStatistics then
		pcall(function() GameStatistics.ResumeMatch() end)
	end
	-- Restore ball states
	for _, ball in ipairs(BALLS_FOLDER:GetChildren()) do
		if not ball or not ball:IsDescendantOf(BALLS_FOLDER) then continue end

		if ball:IsA("BasePart") or ball:IsA("MeshPart") or ball:FindFirstChild("Information") then
			-- Safely restore ball physics
			if ball:IsA("BasePart") then
				-- Reset velocity to prevent jittering
				ball.AssemblyLinearVelocity = Vector3.zero
				ball.AssemblyAngularVelocity = Vector3.zero
				-- Force server ownership to ensure physics consistency
				pcall(function() ball:SetNetworkOwner(nil) end)
				-- STEP 1: Immediately restore CanCollide
				pcall(function() ball.CanCollide = true end)
			end

			-- STEP 2: After 1 second, remove anchor to let ball fall naturally
			task.delay(1, function()
				if ball and ball:IsDescendantOf(BALLS_FOLDER) then
					ball.Anchored = false
					pcall(function() ball.CanTouch = true end)
				end
			end)

			ball:SetAttribute("Paused", nil)
		end
	end
end

function ABHLeague:ThrowBallMiddle()
	local ballInstance = ABHBall:Create(CFrame.new(MIDDLE_POSITION))
	ballInstance.ForceField:Destroy()
	ballInstance.CanTouch = true
end

function ABHLeague:ThrowOff(spawner: Player?)
	local isHome = ABHLeague.CurrentHalf % 2 ~= 0
	local ballInstance = ABHBall:Create(CFrame.new(MIDDLE_POSITION), spawner)
	ballInstance.AssemblyLinearVelocity = Vector3.zero
	ballInstance.AssemblyAngularVelocity = Vector3.zero
	ballInstance.Anchored = true
	ballInstance.ForceField:Destroy()

	local forceField = if isHome then HOME_AREA:Clone() else AWAY_AREA:Clone()
	forceField.Name = "ForceField"
	forceField:SetAttribute("isHome", isHome)
	forceField:SetAttribute("Ignore", true)
	forceField:SetAttribute("Took", false)
	forceField:SetAttribute("TakerUserId", 0)
	forceField.Parent = ballInstance

	local timerTextLabel = forceField.Timer.Seconds
	forceField.Timer.MaxDistance = 60 -- Raposa: Nao visto de longe
	local currentTimer = THROW_TIMER_LIMIT
	timerTextLabel.Text = string.format("%.1f", currentTimer)

	local janitor = Janitor.new()
	janitor:LinkToInstance(forceField)
	janitor:Add(forceField.Touched:Connect(function(touchingPart)
		local player = Players:GetPlayerFromCharacter(touchingPart.Parent)
		if not player then
			return
		end

		local teamName = player.Team.Name
		if teamName == "Officials" then
			return
		end

		local isTook = forceField:GetAttribute("Took")
		local takerId = forceField:GetAttribute("TakerUserId")
		local character = touchingPart.Parent
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart then return end

		-- Check if player is on the allowed team
		local isAllowedTeam = false
		if forceField:GetAttribute("isHome") == true then
			if teamName:find("Home") and not teamName:find("Substitutes") then
				isAllowedTeam = true
			end
		else
			if teamName:find("Away") and not teamName:find("Substitutes") then
				isAllowedTeam = true
			end
		end

		if isTook then
			-- If already took, ONLY the taker can stay inside (not even teammates)
			if player.UserId == takerId then
				return
			end
		else
			-- If not took yet, and player is on allowed team, they pick it up
			if isAllowedTeam then
				forceField:SetAttribute("Took", true)
				forceField:SetAttribute("TakerUserId", player.UserId)

				-- Raposa: Trava movimento e pulo ao pegar a bola
				LockPlayerToForceField(player, forceField)

				-- Teleport to ball for consistent pickup experience
				humanoidRootPart.CFrame = CFrame.new(Vector3.new(ballInstance.Position.X, ballInstance.Position.Y + 3, ballInstance.Position.Z))
				return
			end
		end

		-- Raposa: RestriàƒÂ§àƒÂµes de entrada/saàƒÂ­da
		-- Se for o time dono da bola e tentou sair (ou entrou e nàƒÂ£o àƒÂ© o taker), levamos pro meio do forcefield
		-- Se for o time adversàƒÂ¡rio, expulsamos
		if isAllowedTeam then
			-- Se jàƒÂ¡ foi pego e nàƒÂ£o àƒÂ© o taker, ou se estàƒÂ¡ tentando sair, volta pro centro
			humanoidRootPart.CFrame = CFrame.new(ballInstance.Position + Vector3.new(0, 3, 0))
		else
			-- Time adversàƒÂ¡rio: Expulsa para a sua metade
			local presumedOppositePosition = if isHome then AWAY_POS else HOME_POS
			humanoidRootPart.CFrame = CFrame.new(presumedOppositePosition)
		end
	end), "Disconnect")

	while currentTimer > 0 and forceField:IsDescendantOf(workspace) do
		task.wait(0.1)

		currentTimer -= 0.1
		timerTextLabel.Text = string.format("%.1f", currentTimer)
	end

	if currentTimer <= 0 and forceField then
		forceField:Destroy()
	end
end

function ABHLeague:BeginLeague(player: Player?)
	lastAttackJanitor:Cleanup()
	ABHLeague:DoCleaning()
	ABHLeague:SetMatchState(true)
	DATA_FOLDER.LastAttack.Value = false
	DATA_FOLDER.AddedTime.Value = 0
	MATCH_PAUSED.Value = false
	BALL_TIMER.Value = true

	if CardSystem then
		CardSystem:ResetAll()
	end

	-- Teleport players to their respective areas
	for _, p in ipairs(Players:GetPlayers()) do
		local character = p.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp then
			local teamName = p.Team and p.Team.Name or ""
			if teamName:find("Substitutes") then
				continue
			end

			if teamName:find("Home") then
				if teamName:find("Goalkeeper") then
					hrp.CFrame = CFrame.new(HOME_GK_POS)
				else
					hrp.CFrame = CFrame.new(HOME_POS)
				end
				hrp.AssemblyLinearVelocity = Vector3.zero
				hrp.AssemblyAngularVelocity = Vector3.zero
			elseif teamName:find("Away") then
				if teamName:find("Goalkeeper") then
					hrp.CFrame = CFrame.new(AWAY_GK_POS)
				else
					hrp.CFrame = CFrame.new(AWAY_POS)
				end
				hrp.AssemblyLinearVelocity = Vector3.zero
				hrp.AssemblyAngularVelocity = Vector3.zero
			end
		end
	end

	-- Begin handling: ensure only two halves
	if ABHLeague.CurrentHalf < 1 then
		ABHLeague.CurrentHalf = 1

		DATA_FOLDER.HomeScore.Value = 0
		DATA_FOLDER.AwayScore.Value = 0

		if GameStatistics then
			GameStatistics.StartMatch()
		end
		HALF.Value = ABHLeague.CurrentHalf
	elseif ABHLeague.CurrentHalf == 1 then
		ABHLeague.CurrentHalf = 2
		if GameStatistics then
			GameStatistics.StartHalf(2)
		end
		HALF.Value = ABHLeague.CurrentHalf
		DATA_FOLDER.Timer.Value = 0
		ServerEvents.League:Fire("RESET_TIME")
	else
		-- Already past 2 halves; ignore additional begin calls
		return
	end

	ABHLeague:ThrowOff(player)
	ServerEvents.League:Fire("START")
end

function ABHLeague:FullTime()
	ABHLeague:SetMatchState(false)
	DATA_FOLDER.LastAttack.Value = false
	DATA_FOLDER.AddedTime.Value = 0
	MATCH_PAUSED.Value = false
	BALL_TIMER.Value = false
	lastAttackJanitor:Cleanup()

	-- Finalize and Save stats before resetting
	if GameStatistics then
		pcall(function() 
			GameStatistics.FinishMatch() 
			GameStatistics.Reset()
		end)
	end

	ABHLeague.CurrentHalf = -1
	HALF.Value = 0
	ABHLeague:DoCleaning()
end

function ABHLeague:SpawnFreeThrow(position, isHome: boolean)
	local spawnPosition = position
	local presumedTeam = isHome and "Home" or "Away"
	BALL_TIMER.Value = true

	local ballInstance = ABHBall:Create(CFrame.new(spawnPosition))
	ballInstance.AssemblyLinearVelocity = Vector3.zero
	ballInstance.AssemblyAngularVelocity = Vector3.zero
	ballInstance.Anchored = true

	local forceField = ballInstance.ForceField
	forceField.Parent = ballInstance
	forceField:SetAttribute("isHome", isHome)
	forceField:SetAttribute("Took", false)
	forceField:SetAttribute("TakerUserId", 0)
	forceField.Color = isHome and Color3.fromRGB(0, 0, 255) or Color3.fromRGB(255, 0, 0)
	forceField.Position = spawnPosition
	local r = forceField.Size.X -- Sphere radius

	local timerTextLabel = forceField.Timer.Seconds
	forceField.Timer.MaxDistance = 60 -- Raposa: Nao visto de longe
	local currentTimer = THROW_TIMER_LIMIT
	timerTextLabel.Text = string.format("%.1f", currentTimer)


	local janitor = Janitor.new()
	janitor:LinkToInstance(forceField)
	janitor:Add(forceField.Touched:Connect(function(touchingPart)
		local player = Players:GetPlayerFromCharacter(touchingPart.Parent)
		if not player then
			return
		end

		local teamName = player.Team.Name
		if teamName == "Officials" then
			return
		end

		local isTook = forceField:GetAttribute("Took")
		local takerId = forceField:GetAttribute("TakerUserId")
		local character = touchingPart.Parent
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart then return end

		-- Check if player is on the allowed team
		local isAllowedTeam = false
		if forceField:GetAttribute("isHome") == true then
			if teamName:find("Home") and not teamName:find("Substitutes") then
				isAllowedTeam = true
			end
		else
			if teamName:find("Away") and not teamName:find("Substitutes") then
				isAllowedTeam = true
			end
		end

		if isTook then
			-- If already took, ONLY the taker can stay inside (not even teammates)
			if player.UserId == takerId then
				return
			end
		else
			-- If not took yet, and player is on allowed team, they pick it up
			if isAllowedTeam then
				forceField:SetAttribute("Took", true)
				forceField:SetAttribute("TakerUserId", player.UserId)

				-- Raposa: Trava movimento e pulo ao pegar a bola
				LockPlayerToForceField(player, forceField)

				-- Teleport to ball for consistent pickup experience
				humanoidRootPart.CFrame = CFrame.new(Vector3.new(ballInstance.Position.X, ballInstance.Position.Y + 3, ballInstance.Position.Z))
				return
			end
		end

		local hrpPosition = humanoidRootPart.Position

		-- d is the vector which represents the distance from the sphere and the player
		local d = vector.create(hrpPosition.X - forceField.Position.X, hrpPosition.Y - forceField.Position.Y, hrpPosition.Z - forceField.Position.Z)
		local unitDistance = vector.normalize(d)
		local determinedSpherePoint = vector.create(
			forceField.Position.X + r*unitDistance.x,
			forceField.Position.Y + r*unitDistance.y,
			forceField.Position.Z + r*unitDistance.z
		)

		local displacement = determinedSpherePoint + (unitDistance * DISPLACEMENT_OFFSET)
		local displacementPosition = Vector:VectorLibToVector3(displacement)
		humanoidRootPart.CFrame = CFrame.new(displacementPosition)
	end))

	local teamPlayers = Teams:FindFirstChild(presumedTeam.." Team"):GetPlayers()
	local goalkeeper = Teams:FindFirstChild("-"..presumedTeam.." Goalkeeper"):GetPlayers()[1]
	if goalkeeper then
		table.insert(teamPlayers, goalkeeper)
	end

	for i, player in teamPlayers do
		LEAGUE_EVENT:FireClient(player, "TEAM_FREE_THROW_CLIENT", ballInstance.Name)
	end

	while currentTimer > 0 and forceField:IsDescendantOf(workspace) do
		task.wait(0.1)

		currentTimer -= 0.1
		timerTextLabel.Text = string.format("%.1f", currentTimer)
	end

	if currentTimer <= 0 and forceField then
		forceField:Destroy()
	end
end

function ABHLeague:Reset()
	ABHLeague:SetMatchState(false)
	DATA_FOLDER.LastAttack.Value = false
	DATA_FOLDER.AddedTime.Value = 0
	DATA_FOLDER.HomeScore.Value = 0
	DATA_FOLDER.AwayScore.Value = 0
	DATA_FOLDER.Timer.Value = 0
	MATCH_PAUSED.Value = false
	BALL_TIMER.Value = false
	ABHLeague.CurrentHalf = -1
	HALF.Value = 0
	ballTimeViolations = {}
	violationCooldowns = {}

	-- Clean up any remaining BallOwnership motors
	local teamPlayers = Utils:MergeTables(
		Teams:FindFirstChild("Home Team"):GetPlayers(),
		Teams:FindFirstChild("-Home Goalkeeper"):GetPlayers(),
		Teams:FindFirstChild("Away Team"):GetPlayers(),
		Teams:FindFirstChild("-Away Goalkeeper"):GetPlayers()
	)
	for _, player in teamPlayers do
		if player.Character then
			local ownership = player.Character:FindFirstChild("BallOwnership")
			if ownership then
				ownership:Destroy()
			end
		end
	end

	-- Reset game statistics and timer
	if GameStatistics then
		GameStatistics.Reset()
	end

	if CardSystem then
		CardSystem:ResetAll()
	end

	ServerEvents.League:Fire("RESET")

	lastAttackJanitor:Cleanup()
	ABHLeague:DoCleaning()
end

function ABHLeague:SpawnPenalty(isHome: boolean, isHomeGLT: boolean)
	if penaltyCooldown then
		return
	end
	penaltyCooldown = true
	BALL_TIMER.Value = true

	local presumedTeam = isHome and "Home" or "Away"
	local presumedForceField = HOME_PENALTY_FC
	local presumedPosition = HOME_PT_POS
	if not isHomeGLT then
		presumedPosition = AWAY_PT_POS
		presumedForceField = AWAY_PENALTY_FC
	end

	local forceField = presumedForceField:Clone()
	forceField.Name = "ForceField"
	local ballInstance = ABHBall:Create(CFrame.new(presumedPosition))
	ballInstance.AssemblyLinearVelocity = Vector3.zero
	ballInstance.AssemblyAngularVelocity = Vector3.zero
	ballInstance.Anchored = true

	local timer = ballInstance.ForceField.Timer:Clone()
	timer.Size = UDim2.fromScale(16, 16)
	timer.StudsOffset = Vector3.new(0,0,0)
	timer.MaxDistance = 60 -- Raposa: Nao visto de longe
	timer.Parent = forceField

	ballInstance.ForceField:Destroy()

	forceField.Parent = ballInstance
	forceField:SetAttribute("isHome", isHome)
	forceField:SetAttribute("Took", false)
	forceField:SetAttribute("TakerUserId", 0)
	forceField.Color = isHome and Color3.fromRGB(0, 0, 255) or Color3.fromRGB(255, 0, 0)

	local timerTextLabel = timer.Seconds
	local currentTimer = PENALTY_TIMER_LIMIT
	timerTextLabel.Text = string.format("%.1f", currentTimer)

	local janitor = Janitor.new()
	janitor:Add(function()
		penaltyCooldown = false
	end)
	janitor:LinkToInstance(forceField)
	janitor:Add(forceField.Touched:Connect(function(touchingPart)
		local player = Players:GetPlayerFromCharacter(touchingPart.Parent)
		if not player then
			return
		end

		local teamName = player.Team.Name
		if teamName == "Officials" then
			return
		end

		local isTook = forceField:GetAttribute("Took")
		local takerId = forceField:GetAttribute("TakerUserId")
		local character = touchingPart.Parent
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart then return end

		-- Check if player is on the allowed team
		local isAllowedTeam = false
		if forceField:GetAttribute("isHome") == true then
			if teamName:find("Home") and not teamName:find("Substitutes") then
				isAllowedTeam = true
			end
		else
			if teamName:find("Away") and not teamName:find("Substitutes") then
				isAllowedTeam = true
			end
		end

		if isTook then
			-- If already took, only the taker or goalkeepers can stay inside
			if player.UserId == takerId or teamName:find("Goalkeeper") then
				return
			end
		else
			-- If not took yet, and player is on allowed team (and not a GK), they pick it up
			if isAllowedTeam and not teamName:find("Goalkeeper") then
				forceField:SetAttribute("Took", true)
				forceField:SetAttribute("TakerUserId", player.UserId)

				-- Raposa: Trava movimento e pulo ao pegar a bola
				LockPlayerToForceField(player, forceField)

				-- Teleport to ball for consistent experience
				humanoidRootPart.CFrame = CFrame.new(Vector3.new(ballInstance.Position.X, ballInstance.Position.Y + 3, ballInstance.Position.Z))
				return
			end
			-- Goalkeepers can always stay in penalty area before it's took
			if teamName:find("Goalkeeper") then
				return
			end
		end

		local xDisplacement
		if presumedPosition.X < 0 then
			xDisplacement = DISPLACEMENT_OFFSET * 2
		else
			xDisplacement = -DISPLACEMENT_OFFSET * 2
		end

		humanoidRootPart.CFrame = CFrame.new(Vector3.new(humanoidRootPart.Position.X + xDisplacement, humanoidRootPart.Position.Y, humanoidRootPart.Position.Z))
	end))

	local teamPlayers = Teams:FindFirstChild(presumedTeam.." Team"):GetPlayers()
	local goalkeeper = Teams:FindFirstChild("-"..presumedTeam.." Goalkeeper"):GetPlayers()[1]
	if goalkeeper then
		table.insert(teamPlayers, goalkeeper)
	end

	for i, player in teamPlayers do
		LEAGUE_EVENT:FireClient(player, "TEAM_FREE_THROW_CLIENT", ballInstance.Name)
	end

	while currentTimer > 0 and forceField:IsDescendantOf(workspace) do
		task.wait(0.1)

		currentTimer -= 0.1
		timerTextLabel.Text = string.format("%.1f", currentTimer)
	end

	if currentTimer <= 0 and forceField then
		-- Raposa: Dar violaàƒÆ’à‚Â§àƒÆ’à‚Â£o para o taker se o tempo acabar no pàƒÆ’à‚Âªnalti
		local takerUserId = forceField:GetAttribute("TakerUserId")
		if takerUserId and takerUserId > 0 then
			local player = Players:GetPlayerByUserId(takerUserId)
			if player then
				ABHLeague:IssueBallTimeViolation(player)
			end
		end
		forceField:Destroy()
	end
end

function ABHLeague:SpawnBallToGoalkeeper(team: "Home" | "Away")
	local goalkeeper = Teams:FindFirstChild("-"..team.." Goalkeeper"):GetPlayers()[1]

	local presumedPosition = if team == "Home" then HOME_GK_POS else AWAY_GK_POS
	local ballInstance = ABHBall:Create(CFrame.new(presumedPosition))
	ballInstance.ForceField:Destroy()

	if goalkeeper then
		local character = goalkeeper.Character
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then
				hrp.CFrame = CFrame.new(presumedPosition)
			end
		end
	end

	local refImmunity = ballInstance:FindFirstChild("RefereeImmunity")
	if refImmunity then
		refImmunity:Destroy()
	end
end

function ABHLeague:GoalScored(scoringTeam: "Home" | "Away")
	if not ABHLeague.BeingPlayed then
		return
	end

	local teamScoredOn = if scoringTeam == "Home" then "Away" else "Home"
	local goalkeeper = Teams:FindFirstChild("-"..teamScoredOn.." Goalkeeper"):GetPlayers()[1]

	local presumedPosition = if teamScoredOn == "Home" then HOME_GK_POS else AWAY_GK_POS
	local ballInstance = ABHBall:Create(CFrame.new(presumedPosition))
	ballInstance.ForceField:Destroy()

	if goalkeeper then
		local character = goalkeeper.Character
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then
				hrp.CFrame = CFrame.new(presumedPosition)
			end
		end
	end

	local refImmunity = ballInstance:FindFirstChild("RefereeImmunity")
	if refImmunity then
		refImmunity:Destroy()
	end
end

local function isABHBallOnField(ABHBall: BasePart)
	local position = ABHBall.Position
	local r = ABHBall.Size.X / 2  -- Ball radius

	local xInBounds = (position.X - r) >= BOUNDARY_MIN.X and (position.X + r) <= BOUNDARY_MAX.X
	local zInBounds = (position.Z - r) >= BOUNDARY_MIN.Z and (position.Z + r) <= BOUNDARY_MAX.Z

	return xInBounds and zInBounds
end

function handleOut(ballInstance: SharedTypes.ABHBallInstance, presumedPosition: Vector3)
	local currentPlayer = ballInstance.Information.CurrentPlayerOnBall.Value :: Player?
	local lastThrow = ballInstance.Information.LastThrow.Value :: Player?
	local allowed = false
	local teamName = ""
	local statsPlayer = nil

	if currentPlayer then
		teamName = (currentPlayer.Team :: Team).Name
		statsPlayer = currentPlayer
		allowed = true
	elseif not currentPlayer and lastThrow then
		teamName = (lastThrow.Team :: Team).Name
		statsPlayer = lastThrow
		allowed = true
	end

	-- Avoid weird situations. 
	-- Either a player runs out with the ball or he throwed the ball out
	if not allowed then
		return
	end

	--Raposa adicionou
	-- Record statistics based on whether it was a shot or pass
	if statsPlayer and GameStatistics then
		local isShot = ballInstance:GetAttribute("IsShot") or false
		local isScored = ballInstance:GetAttribute("Scored")
		local isGK = (statsPlayer and (statsPlayer.Team :: Team).Name:find("Goalkeeper"))
		if isShot and not ballInstance:GetAttribute("Saved") and not isScored and not isGK then
			GameStatistics.RecordEvent(statsPlayer, "ShotMiss")
		else
			GameStatistics.RecordEvent(statsPlayer, "Turnover")
		end
	end
	--Fim Raposa

	ABHBall:Ghostball(ballInstance)

	if teamName:find("Home") then
		-- Away posession
		ABHLeague:SpawnFreeThrow(presumedPosition, false)
	elseif teamName:find("Away") then
		-- Home possesion
		ABHLeague:SpawnFreeThrow(presumedPosition, true)
	end
end

function detectSideOut(part: BasePart)
	local cooldown = false
	local presumedZPos
	if part.Position.Z < 0 then
		presumedZPos = LEFT_Z
	else
		presumedZPos = RIGHT_Z
	end


	part.Touched:Connect(function(child)
		if not child:IsDescendantOf(BALLS_FOLDER) then
			return
		end
		if not ABHLeague.BeingPlayed then
			return
		end
		if cooldown then
			return
		end
		cooldown = true

		local ballInstance = child :: SharedTypes.ABHBallInstance
		local presumedPosition = Vector3.new(ballInstance.Position.X, 2, presumedZPos)

		task.wait(OUT_DELAY)

		if child:IsDescendantOf(BALLS_FOLDER) then
			if not isABHBallOnField(ballInstance) then
				coroutine.wrap(handleOut)(ballInstance, presumedPosition)
			end
		end

		cooldown = false
	end)
end

function detectGoalsOut(part: BasePart)
	local cooldown = false
	local isHome = true
	local presumedCornerThrowPos = Vector3.zero

	if part.Position.X < 0 then
		-- It's in home side
		if part.Position.Z < 0 then
			presumedCornerThrowPos = LEFT_HOME_CT
		else
			presumedCornerThrowPos = RIGHT_HOME_CT
		end
	else
		isHome = false
		-- It's in away side
		if part.Position.Z < 0 then
			presumedCornerThrowPos = RIGHT_AWAY_CT
		else
			presumedCornerThrowPos = LEFT_AWAY_CT
		end
	end

	part.Touched:Connect(function(child)
		if not child:IsDescendantOf(BALLS_FOLDER) then
			return
		end
		if not ABHLeague.BeingPlayed then
			return
		end

		local ballInstance = child :: SharedTypes.ABHBallInstance
		if not ballInstance:FindFirstChild("Information") then
			return
		end

		local presumedPosition = presumedCornerThrowPos
		local lastPlayer: Player

		local currentPlayerOnBall = ballInstance.Information.CurrentPlayerOnBall.Value :: Player?
		local lastThrow = ballInstance.Information.LastThrow.Value :: Player?
		local lastlastThrow = ballInstance.Information.LastLastThrow.Value :: Player?
		if currentPlayerOnBall then
			lastPlayer = currentPlayerOnBall
		elseif not currentPlayerOnBall and lastThrow then
			lastPlayer = lastThrow
		end

		if not lastPlayer then
			return
		end

		if cooldown then 
			return
		end

		task.wait(OUT_DELAY)

		if not child:IsDescendantOf(BALLS_FOLDER) then
			return
		end
		if isABHBallOnField(ballInstance) then
			return
		end
		cooldown = true

		if not currentPlayerOnBall then
			if isHome and lastThrow.Team.Name == "-Home Goalkeeper" and lastlastThrow and lastlastThrow.Team.Name:find("Away") then
				ABHBall:Ghostball(ballInstance)
				ABHLeague:SpawnBallToGoalkeeper("Home")
			elseif not isHome and lastThrow.Team.Name == "-Away Goalkeeper" and lastlastThrow and lastlastThrow.Team.Name:find("Home") then
				ABHBall:Ghostball(ballInstance)
				ABHLeague:SpawnBallToGoalkeeper("Away")
			elseif lastThrow.Team.Name:find("Away") and isHome then
				--Raposa adicionou
				-- Record statistics: shot miss or turnover
				if GameStatistics then
					local isSOG = ballInstance:GetAttribute("IsSOG")
					local isScored = ballInstance:GetAttribute("Scored")
					local isGK = lastThrow.Team.Name:find("Goalkeeper")
					if not isSOG and not ballInstance:GetAttribute("Saved") and not isScored and not isGK then
						GameStatistics.RecordEvent(lastThrow, "ShotMiss")
					end
				end
				--Fim Raposa
				ABHBall:Ghostball(ballInstance)
				ABHLeague:SpawnBallToGoalkeeper("Home")
			elseif lastThrow.Team.Name:find("Home") and not isHome then
				--Raposa adicionou
				-- Record statistics: shot miss or turnover
				if GameStatistics then
					local isSOG = ballInstance:GetAttribute("IsSOG")
					local isScored = ballInstance:GetAttribute("Scored")
					local isGK = lastThrow.Team.Name:find("Goalkeeper")
					if not isSOG and not ballInstance:GetAttribute("Saved") and not isScored and not isGK then
						GameStatistics.RecordEvent(lastThrow, "ShotMiss")
					end
				end
				--Fim Raposa
				ABHBall:Ghostball(ballInstance)
				ABHLeague:SpawnBallToGoalkeeper("Away")
			else
				coroutine.wrap(handleOut)(ballInstance, presumedPosition)
			end

			cooldown = false
			return
		end

		if currentPlayerOnBall.Team.Name:find("Away") and isHome then
			--Raposa adicionou
			-- Record statistics: shot miss or turnover
			if GameStatistics then
				local isShot = ballInstance:GetAttribute("IsShot") or false
				local isScored = ballInstance:GetAttribute("Scored")
				local isGK = currentPlayerOnBall.Team.Name:find("Goalkeeper")
				if isShot and not ballInstance:GetAttribute("Saved") and not isScored and not isGK then
					GameStatistics.RecordEvent(currentPlayerOnBall, "ShotMiss")
				else
					GameStatistics.RecordEvent(currentPlayerOnBall, "Turnover")
				end
			end
			--Fim Raposa
			ABHBall:Ghostball(ballInstance)
			ABHLeague:SpawnBallToGoalkeeper("Home")
		elseif currentPlayerOnBall.Team.Name:find("Home") and not isHome then
			--Raposa adicionou
			-- Record statistics: shot miss or turnover
			if GameStatistics then
				local isShot = ballInstance:GetAttribute("IsShot") or false
				local isScored = ballInstance:GetAttribute("Scored")
				local isGK = currentPlayerOnBall.Team.Name:find("Goalkeeper")
				if isShot and not ballInstance:GetAttribute("Saved") and not isScored and not isGK then
					GameStatistics.RecordEvent(currentPlayerOnBall, "ShotMiss")
				else
					GameStatistics.RecordEvent(currentPlayerOnBall, "Turnover")
				end
			end
			--Fim Raposa
			ABHBall:Ghostball(ballInstance)
			ABHLeague:SpawnBallToGoalkeeper("Away")
		else
			coroutine.wrap(handleOut)(ballInstance, presumedPosition)
		end

		cooldown = false
	end)
end

function handleLastAttack(presumedTeam: "Home" | "Away", ballInstance: SharedTypes.ABHBallInstance)
	local ballJanitor = Janitor.new()

	ballInstance.Destroying:Connect(function()
		ballJanitor:Destroy()
	end)

	ballJanitor:Add(ballInstance.Information.CurrentPlayerOnBall:GetPropertyChangedSignal('Value'):Connect(function()
		local currentPlr = ballInstance.Information.CurrentPlayerOnBall.Value :: Player?
		if not currentPlr then
			return
		end

		local team = (currentPlr.Team :: Team).Name
		if team:find(presumedTeam) then
			return
		end
		if team:find("Substitutes") or team == "Officials" or team == "Lobby" then
			return
		end

		-- end the game
		ABHBall:Ghostball(ballInstance)
	end))
end

function onLastAttack(ballInstance : SharedTypes.ABHBallInstance)
	local currentPlayer = ballInstance.Information.CurrentPlayerOnBall
	local lastThrow = ballInstance.Information.LastThrow
	local presumedTeam = "Home"

	if currentPlayer.Value then			
		if not (currentPlayer.Value.Team :: Team).Name:find("Home") then
			presumedTeam = "Away"
		end
	elseif not currentPlayer.Value and lastThrow.Value then
		if not (lastThrow.Value.Team :: Team).Name:find("Home") then
			presumedTeam = "Away"
		end
	end

	coroutine.wrap(handleLastAttack)(presumedTeam, ballInstance)
end

-- LEAGUE EVENTS
ServerEvents.League:Connect(function(action, ...)
	if action == "END_HALF" then
		-- A bola some imediatamente ao acabar o tempo
		ABHLeague:DoCleaning()

		if ABHLeague.CurrentHalf == 1 then
			-- FIM DO 1àƒâ€šà‚Âº TEMPO
			task.spawn(function()
				-- Countdown visual do Admin
				RunAdminCountdown(HALF_TIME_COUNTDOWN)

				-- Countdown de intervalo no placar
				for i = HALF_TIME_COUNTDOWN, 0, -1 do
					DATA_FOLDER.Timer.Value = i
					task.wait(1)
				end
				-- ComeàƒÆ’à‚Â§a o 2àƒâ€šà‚Âº tempo automaticamente
				ABHLeague:BeginLeague()
			end)
		elseif ABHLeague.CurrentHalf == 2 then
			-- FIM DO 2àƒâ€šà‚Âº TEMPO
			task.spawn(function()
				-- Raposa: Limpar bolas imediatamente ao fim do jogo
				ABHLeague:DoCleaning()
				lastAttackJanitor:Cleanup()

				-- Countdown visual do Admin para o reset final
				RunAdminCountdown(FULL_TIME_WAIT)

				-- Espera o tempo configurado apàƒÆ’à‚Â³s o fim do jogo
				task.wait(FULL_TIME_WAIT)

				-- Reseta todo mundo pro lobby e respawna (;re all)
				for _, player in Players:GetPlayers() do
					if Teams:FindFirstChild("Lobby") then
						player.Team = Teams.Lobby
					end
					player:LoadCharacter()
				end

				-- Reseta placar, bola e estatàƒÆ’à‚Â­sticas
				ABHLeague:Reset()
			end)
		end
	elseif action == "CANCEL_LAST_ATTACK" then
		lastAttackJanitor:Cleanup()
	elseif action == "FREE_THROW" then
		local position, isHome = ...
		ABHLeague:SpawnFreeThrow(position, isHome)
	elseif action == "BALL_TIME_VIOLATION" then
		local player = ...
		if player then
			ABHLeague:IssueBallTimeViolation(player)
		end
	elseif action == "PENALTY" then
		local isHome, isHomeGLT = ...
		ABHLeague:SpawnPenalty(isHome, isHomeGLT)
	end
end)

LEAGUE_EVENT.OnServerEvent:Connect(function(player, action, ...)
	if action == "CALL_FOR_PAUSE" then
		local userId = player.UserId
		if ABHLeague.HomeTeamManagerUserId ~= userId and ABHLeague.AwayTeamManagerUserId ~= userId then
			return
		end

		for i, official in Teams.Officials:GetPlayers() do
			LEAGUE_EVENT:FireClient(player, "CALL_FOR_PAUSE", player.Name)
		end
	end
end)

local globalTeleportData = nil

Players.PlayerAdded:Connect(function(player)
	if not globalTeleportData then
		local joinData = player:GetJoinData()
		globalTeleportData = joinData and joinData.TeleportData
		if globalTeleportData and globalTeleportData.Match ~= nil then
			-- Restore global state once
			DATA_FOLDER.Timer.Value = globalTeleportData.Timer
			DATA_FOLDER.HomeScore.Value = globalTeleportData.HomeScore
			DATA_FOLDER.AwayScore.Value = globalTeleportData.AwayScore
			DATA_FOLDER.Half.Value = globalTeleportData.Half
			DATA_FOLDER.HomeName.Value = globalTeleportData.HomeName
			DATA_FOLDER.AwayName.Value = globalTeleportData.AwayName
			DATA_FOLDER.AddedTime.Value = globalTeleportData.AddedTime or 0
			MATCH_PAUSED.Value = globalTeleportData.MatchPaused

			ABHLeague:SetMatchState(globalTeleportData.Match)
			ABHLeague.CurrentHalf = globalTeleportData.Half or -1
			ServerEvents.League:Fire("SET_TIME", globalTeleportData.Timer)

			-- Raposa: Restaurar bolas
			if globalTeleportData.BallsData then
				for _, bData in ipairs(globalTeleportData.BallsData) do
					local ball = ABHBall:Create(bData.CFrame)
					ball.AssemblyLinearVelocity = bData.Velocity
				end
			end

			-- Raposa: ForàƒÂ§ar pausa se a partida estiver ativa
			if globalTeleportData.Match then
				task.delay(1, function()
					ABHLeague:PauseMatch()
				end)
			end
		end
	end

	if globalTeleportData and globalTeleportData.PlayerTeams then
		local teamName = globalTeleportData.PlayerTeams[tostring(player.UserId)]
		if teamName and Teams:FindFirstChild(teamName) then
			task.delay(0.5, function()
				player.Team = Teams[teamName]
			end)
		end
	end

	-- Raposa: Restaurar posiàƒÂ§àƒÂ£o do jogador (apenas uma vez no rejoin)
	if globalTeleportData and globalTeleportData.PlayerPositions then
		local savedPos = globalTeleportData.PlayerPositions[tostring(player.UserId)]
		if savedPos then
			local connection
			connection = player.CharacterAdded:Connect(function(character)
				local hrp = character:WaitForChild("HumanoidRootPart", 5)
				if hrp then
					task.defer(function()
						character:PivotTo(savedPos)
					end)
				end
				if connection then
					connection:Disconnect()
					connection = nil
				end
			end)
		end
	end

	if ABHLeague.HomeTeamManagerUserId == player.UserId or ABHLeague.AwayTeamManagerUserId == player.UserId then
		LEAGUE_EVENT:FireClient(player, "CHOOSEN_MANAGER")
	end
end)

-- OUT DETECTIONS
for _, part in OUT_FOLDER:GetChildren() do
	if part:IsA("BasePart") then
		coroutine.wrap(detectSideOut)(part)
	end
end

for _, part in OUT_FOLDER.AwayGK:GetChildren() do
	if part:IsA("BasePart") then
		coroutine.wrap(detectGoalsOut)(part)
	end
end

for _, part in OUT_FOLDER.HomeGK:GetChildren() do
	if part:IsA("BasePart") then
		coroutine.wrap(detectGoalsOut)(part)
	end
end

return ABHLeague






