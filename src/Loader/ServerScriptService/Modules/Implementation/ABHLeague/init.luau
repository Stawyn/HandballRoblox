--[[
    ================================================================================
    MODULO: ABHLeague
    ================================================================================
    Descricao: Sistema central de gerenciamento de partidas do jogo ABH Handball.
               Controla o fluxo completo da partida, desde o inicio ate o fim.
    
    Funcionalidades:
        - Gerenciamento de tempos (1o e 2o tempo)
        - Controle de pausa/retomada
        - Sistema de ThrowOff (saida de bola)
        - Sistema de Free Throw e Penalty
        - Sistema de Out (lateral/linha de fundo)
        - Violacoes de tempo de posse
        - Integracao com CardSystem, GameStatistics, ABHBall
        - Watchdog para garantir que a partida tenha bolas
    
    Estados da Partida:
        - BeingPlayed: Partida em andamento
        - MatchPaused: Partida pausada
        - CurrentHalf: -1 (nao iniciada), 1 (1o tempo), 2 (2o tempo)
    
    Dependencias:
        - ABHBall: Criacao e manipulacao de bolas
        - CardSystem: Sistema de cartoes
        - GameStatistics: Registro de estatisticas
        - ServerEvents: Eventos internos do servidor
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: SERVICOS
--// ============================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local RunService = game:GetService("RunService")

--// ============================================================================
--// SETOR: INICIALIZACAO DE DADOS
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
--// SETOR: MODULO
--// ============================================================================

local ABHLeague = {
	HomeTeamManagerUserId = 0,
	AwayTeamManagerUserId = 0,
	CurrentHalf = -1,
	BeingPlayed = false,
	lastGlobalThrower = nil,
	StopWatchdogUntil = 0,
	_currentResumeId = 0  -- Bug #10: Flag para evitar race conditions em pause/resume rápido
}

--// ============================================================================
--// SETOR: DEPENDENCIAS
--// ============================================================================

local GameStatistics = require("../Systems/GameStatistics")
local ABHBall = require("../Systems/ABHBAll")
local CardSystem = require(ReplicatedStorage.Modules.Systems.CardSystem)
local Janitor = require("../../../ReplicatedStorage/Utilities/Janitor")
local SharedTypes = require("../../../ReplicatedStorage/Utilities/SharedTypes")
local Vector = require("../../../ReplicatedStorage/Utilities/Vector")
local Utils = require("../../../ReplicatedStorage/Utilities/Utils")
local ServerEvents = require("./ServerEvents")
local Maid = require("../../../ReplicatedStorage/Utilities/Maid")

-- Raposa: Registrar ultimo jogador que jogou a bola
ServerEvents.League:Connect(function(action, player)
	if action == "PLAYER_THROW" then
		ABHLeague.lastGlobalThrower = player
	end
end)

--// ============================================================================
--// SETOR: REFERENCIAS E CONSTANTES
--// ============================================================================

local BALLS_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Balls") :: Folder
local NETWORK_FOLDER = ReplicatedStorage:WaitForChild("Network") :: Folder
local LEAGUE_EVENT = NETWORK_FOLDER:WaitForChild("LeagueEvent") :: RemoteEvent
local REFEREE_EVENT = NETWORK_FOLDER:WaitForChild("Referee") :: RemoteEvent
local OUT_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Out") :: Folder
local REAL_FIELD = workspace:WaitForChild("Core"):WaitForChild("Field"):WaitForChild("RealField")
local ANTI_INVADE = ReplicatedStorage:WaitForChild("Anti-Invade")

-- Configuracoes de tempo (modo de teste)
local TEST_MODE = false -- Mude para true se quiser usar os tempos de teste
local HALF_TIME_COUNTDOWN = if TEST_MODE then 15 else 30
local FULL_TIME_WAIT = if TEST_MODE then 15 else 30  -- Bug #17: Reduzido de 120 para 30 segundos

--// ============================================================================
--// SETOR: FUNCOES INTERNAS
--// ============================================================================

--- Dispara countdown do Kohls Admin se disponivel
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
	if not hrp or not humanoid or humanoid.Health <= 0 then return end

	-- Raposa: Anular velocidade horizontal, manter Y para cair
	hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)
	hrp.AssemblyAngularVelocity = Vector3.zero

	task.spawn(function()
		-- Aguarda o jogador pegar a bola de fato
		character:WaitForChild("BallOwnership", 10)
		if not forceField:IsDescendantOf(workspace) then return end

		local lockJanitor = Janitor.new()

		-- Salvar posicao X e Z para travar
		local lockX = hrp.Position.X
		local lockZ = hrp.Position.Z

		-- Usar AlignPosition para travar apenas X e Z
		local attachment = hrp:FindFirstChild("RootAttachment") or Instance.new("Attachment", hrp)
		
		local alignPos = Instance.new("AlignPosition")
		alignPos.Name = "ForceFieldLockXZ"
		alignPos.Attachment0 = attachment
		alignPos.Mode = Enum.PositionAlignmentMode.OneAttachment
		alignPos.MaxForce = math.huge
		alignPos.MaxVelocity = math.huge
		alignPos.Responsiveness = 200
		alignPos.Parent = hrp
		lockJanitor:Add(alignPos)

		-- Atualizar posicao alvo continuamente (manter X e Z fixos, Y livre)
		local heartbeatConn = RunService.Heartbeat:Connect(function()
			if hrp and hrp.Parent and alignPos and alignPos.Parent then
				alignPos.Position = Vector3.new(lockX, hrp.Position.Y, lockZ)
			end
		end)
		lockJanitor:Add(heartbeatConn, "Disconnect")

		-- Issue 5: Desabilita pulo E movimento
		local oldJumpPower = humanoid.JumpPower
		local oldJumpHeight = humanoid.JumpHeight
		local oldWalkSpeed = humanoid.WalkSpeed
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid.WalkSpeed = 0

		lockJanitor:Add(function()
			-- Cleanup
			if alignPos and alignPos.Parent then
				alignPos:Destroy()
			end
			-- Restaura valores apenas se o humanoide ainda existir e estiver vivo
			if humanoid and humanoid.Parent and humanoid.Health > 0 then
				humanoid.JumpPower = oldJumpPower
				humanoid.JumpHeight = oldJumpHeight
				humanoid.WalkSpeed = oldWalkSpeed
			end
		end)

		-- Limpa tudo quando o forcefield sumir ou jogador morrer/sair
		lockJanitor:LinkToInstance(forceField)
		lockJanitor:Add(humanoid.Died:Connect(function() lockJanitor:Cleanup() end), "Disconnect")
		lockJanitor:Add(player.CharacterRemoving:Connect(function() lockJanitor:Cleanup() end), "Disconnect")
	end)
end

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

--// ============================================================================
--// SETOR: ESTADO
--// ============================================================================

local ballTimeViolations = {}
local violationCooldowns = {}

--// ============================================================================
--// SETOR: FUNCOES PUBLICAS - CONTROLE DE PARTIDA
--// ============================================================================

--- Emite violacao de tempo de posse de bola
-- @param player Player - Jogador que cometeu a violacao
function ABHLeague:IssueBallTimeViolation(player: Player)
	local now = tick()
	if violationCooldowns[player.UserId] and now - violationCooldowns[player.UserId] < 5 then
		return
	end
	violationCooldowns[player.UserId] = now

	ballTimeViolations[player.UserId] = (ballTimeViolations[player.UserId] or 0) + 1
	local count = ballTimeViolations[player.UserId]

	if count == 2 then
		-- LEAGUE_EVENT:FireAllClients("BALL_TIME_VIOLATION", player.Name, "Cartao Amarelo!")
		CardSystem:GiveYellow(player)
	elseif count >= 4 then
		-- LEAGUE_EVENT:FireAllClients("BALL_TIME_VIOLATION", player.Name, "Cartao Vermelho!")

		-- Dropar a bola se estiver segurando
		if player.Character then
			local ownership = player.Character:FindFirstChild("BallOwnership")
			if ownership then
				ownership:Destroy()
				pcall(function()
					REFEREE_EVENT:FireClient(player, {action = "BALL_DROPPED_PAUSE"})
				end)
			end

			-- Teletransportar para o spawn apos a troca de time
			task.spawn(function()
				task.wait(0.5) -- Espera o motor do Roblox processar a troca de time se necessÃƒÆ’Ã‚Â¡rio
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
				-- Raposa: Nao respawnar se as bolas foram limpas manualmente recentemente (cooldown de 10s)
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

		-- Raposa: Remover SpawnTool e KeeperTool de quem estiver no Lobby ao comecar o jogo
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
	
	-- Bug #10: Gerar ID único para este resume
	local resumeId = tick()
	ABHLeague._currentResumeId = resumeId
	
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
			-- Bug #10: Verificar se este resume ainda é o mais recente
			task.delay(1, function()
				if ABHLeague._currentResumeId ~= resumeId then
					return -- Outro pause/resume foi chamado
				end
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

				-- Issue 4: Teleport para o CENTRO do ForceField (mesma altura da bola)
				local safePos = Vector3.new(ballInstance.Position.X, ballInstance.Position.Y, ballInstance.Position.Z)
				humanoidRootPart.CFrame = CFrame.new(safePos)
				humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
				humanoidRootPart.AssemblyAngularVelocity = Vector3.zero
				return
			end
		end

		-- Raposa: Restricoes de entrada/saida
		-- Se for o time dono da bola e tentou sair (ou entrou e nao e o taker), levamos pro meio do forcefield
		-- Se for o time adversario, expulsamos
		if isAllowedTeam then
			-- Issue 4: Volta pro centro (mesma altura da bola)
			if ballInstance and ballInstance.Parent then
				humanoidRootPart.CFrame = CFrame.new(ballInstance.Position.X, ballInstance.Position.Y, ballInstance.Position.Z)
				humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
			end
		else
			-- Time adversario: Expulsa para a sua metade
			local presumedOppositePosition = if isHome then AWAY_POS else HOME_POS
			humanoidRootPart.CFrame = CFrame.new(presumedOppositePosition)
		end
	end), "Disconnect")

	while currentTimer > 0 and forceField:IsDescendantOf(workspace) do
		task.wait(0.1)

		currentTimer -= 0.1
		pcall(function()
			if timerTextLabel and timerTextLabel.Parent then
				timerTextLabel.Text = string.format("%.1f", currentTimer)
			end
		end)
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
			-- Bug #1: Filtrar Officials e Lobby no teleporte
			if teamName:find("Substitutes") or teamName == "Officials" or teamName == "Lobby" then
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
	
	-- Raposa Bugfix: Desativar colisão inicialmente para dar tempo do jogador sair
	forceField.CanCollide = false 
	
	task.delay(0.75, function()
		if forceField and forceField.Parent then
			forceField.CanCollide = true
		end
	end)

	local r = forceField.Size.X -- Sphere radius

	-- Raposa: Empurrar jogadores próximos para evitar flinging (Physics Glitch fix)
	local CLEAR_RADIUS = 7 -- Aumentado para garantir segurança fora do ForceField
	for _, player in Players:GetPlayers() do
		local char = player.Character
		if char and char:FindFirstChild("HumanoidRootPart") then
			local hrp = char.HumanoidRootPart
			-- Calcular distancia horizontal apenas (cilindro)
			local flatPlayerPos = Vector3.new(hrp.Position.X, 0, hrp.Position.Z)
			local flatSpawnPos = Vector3.new(spawnPosition.X, 0, spawnPosition.Z)
			
			local dist = (flatPlayerPos - flatSpawnPos).Magnitude
			
			if dist < CLEAR_RADIUS then
				-- Calcular direção de empurrão HORIZONTAL
				local dir = (flatPlayerPos - flatSpawnPos).Unit
				if dir.Magnitude == 0 or dir.X ~= dir.X then -- Check NaN/Zero
					-- Se estiver exatamente no centro, empurrar para tras ou para o lado
					dir = Vector3.new(1, 0, 0)
				end
				
				-- Empurrar para a borda + pequena margem, SUBINDO um pouco para não clipar no chão
				local pushVector = dir * (CLEAR_RADIUS + 1)
				local newPos = Vector3.new(spawnPosition.X + pushVector.X, hrp.Position.Y + 2, spawnPosition.Z + pushVector.Z)
				
				hrp.CFrame = CFrame.new(newPos, newPos + hrp.CFrame.LookVector)
				hrp.AssemblyLinearVelocity = Vector3.zero -- Resetar velocidade para evitar inércia
			end
		end
	end

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
			if isAllowedTeam and player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
				forceField:SetAttribute("Took", true)
				forceField:SetAttribute("TakerUserId", player.UserId)

				-- Raposa: Trava movimento e pulo ao pegar a bola
				LockPlayerToForceField(player, forceField)

				-- Teleport to ball for consistent pickup experience
				-- Safety Bounds Check
				local safePos = Vector3.new(ballInstance.Position.X, ballInstance.Position.Y + 3, ballInstance.Position.Z)
				if ballInstance.Position.Y < -50 or ballInstance.Position.Y > 200 then
					safePos = Vector3.new(0, 5, 0)
				end
				
				humanoidRootPart.CFrame = CFrame.new(safePos)
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
		pcall(function() 
			if timerTextLabel and timerTextLabel.Parent then
				timerTextLabel.Text = string.format("%.1f", currentTimer)
			end
		end)
	end

	if currentTimer <= 0 and forceField then
		-- Raposa: Dar violaÃƒÂ§ÃƒÂ£o para o taker se o tempo acabar no pÃƒÂªnalti
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
			-- FIM DO 1Ã‚Âº TEMPO
			task.spawn(function()
				-- Countdown visual do Admin
				RunAdminCountdown(HALF_TIME_COUNTDOWN)

				-- Countdown de intervalo no placar
				for i = HALF_TIME_COUNTDOWN, 0, -1 do
					DATA_FOLDER.Timer.Value = i
					task.wait(1)
				end
				-- ComeÃƒÂ§a o 2Ã‚Âº tempo automaticamente
				ABHLeague:BeginLeague()
			end)
		elseif ABHLeague.CurrentHalf == 2 then
			-- FIM DO 2Ã‚Âº TEMPO
			task.spawn(function()
				-- Raposa: Limpar bolas imediatamente ao fim do jogo
				ABHLeague:DoCleaning()
				lastAttackJanitor:Cleanup()

				-- Countdown visual do Admin para o reset final
				RunAdminCountdown(FULL_TIME_WAIT)

				-- Espera o tempo configurado apÃƒÂ³s o fim do jogo
				task.wait(FULL_TIME_WAIT)

				-- Reseta todo mundo pro lobby e respawna (;re all)
				for _, player in Players:GetPlayers() do
					if Teams:FindFirstChild("Lobby") then
						player.Team = Teams.Lobby
					end
					player:LoadCharacter()
				end

				-- Reseta placar, bola e estatÃƒÂ­sticas
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

			-- Raposa: ForÃ§ar pausa se a partida estiver ativa
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

	-- Raposa: Restaurar posiÃ§Ã£o do jogador (apenas uma vez no rejoin)
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





