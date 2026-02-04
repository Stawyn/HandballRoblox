--[[
	================================================================================
	MÓDULO: ABHBall (Sistema Principal de Bola)
	================================================================================
	
	Descrição:
		Módulo central que gerencia toda a física, interações e comportamento
		das bolas no jogo ABH. Controla:
		- Criação e destruição de bolas
		- Sistema de posse (ownership)
		- Física de arrasto (drag) e forças verticais
		- Detecção de tackles e saves
		- Timer de posse e violações
		- Estatísticas de jogo (passes, chutes, roubos)
	
	Autor: Sistema ABH
	Refatorado: Documentação e organização por setores
	
	AVISO: Este é um módulo crítico. Alterações na física podem quebrar o jogo.
	================================================================================
]]

--// ============================================================================
--// SETOR: Definição do Módulo
--// ============================================================================

local ABHBall = {}

--// ============================================================================
--// SETOR: Dependências Externas
--// ============================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UtilitiesFolder = ReplicatedStorage:WaitForChild("Utilities")
local ModulesFolder = ReplicatedStorage:WaitForChild("Modules")

local Maid = require(UtilitiesFolder:WaitForChild("Maid"))
local Janitor = require(UtilitiesFolder:WaitForChild("Janitor"))
local FixedPower = require(ModulesFolder:WaitForChild("Implementation"):WaitForChild("ThrowPower"))
local SharedTypes = require(UtilitiesFolder:WaitForChild("SharedTypes"))
local VectorLib = require(UtilitiesFolder:WaitForChild("Vector"))
local SharedAttributes = require(ModulesFolder:WaitForChild("Implementation"):WaitForChild("SharedAttributes"))
local Utils = require(UtilitiesFolder:WaitForChild("Utils"))
local ServerEvents = require(script.Parent.Parent:WaitForChild("Implementation"):WaitForChild("ServerEvents"))

-- Raposa: Sistema de estatísticas
local GameStatistics = require(script.Parent:WaitForChild("GameStatistics"))

--// ============================================================================
--// SETOR: Serviços do Roblox
--// ============================================================================

local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Teams = game:GetService("Teams")

--// ============================================================================
--// SETOR: Referências de Times
--// ============================================================================

local HOME_TEAM = Teams:WaitForChild("Home Team")
local HOME_GK = Teams:WaitForChild("-Home Goalkeeper")
local AWAY_GK = Teams:WaitForChild("-Away Goalkeeper")
local AWAY_TEAM = Teams:WaitForChild("Away Team")

--// ============================================================================
--// SETOR: Referências do Workspace e Storage
--// ============================================================================

local BALL_INSTANCE = ServerStorage:WaitForChild("ABHBall") :: SharedTypes.ABHBallInstance
local CORE_FOLDER = workspace:WaitForChild("Core")
local DATA_FOLDER = CORE_FOLDER:WaitForChild("Data") 
local BALLS_FOLDER = CORE_FOLDER:WaitForChild("Balls") 
local BALL_TIMER = DATA_FOLDER:WaitForChild("BallTimer")
local MATCH_VALUE = DATA_FOLDER:WaitForChild("Match")
local MATCH_PAUSED = DATA_FOLDER:WaitForChild("MatchPaused")
local HOME_GLT = CORE_FOLDER:WaitForChild("GLT"):WaitForChild("Home")
local AWAY_GLT = CORE_FOLDER:WaitForChild("GLT"):WaitForChild("Away")

local NETWORK_FOLDER = ReplicatedStorage:WaitForChild("Network") :: Folder
local LEAGUE_EVENT = NETWORK_FOLDER:WaitForChild("LeagueEvent") :: RemoteEvent
local HOME_AREA = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("HomeArea") :: BasePart
local AWAY_AREA = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("AwayArea") :: BasePart

--// ============================================================================
--// SETOR: Constantes de Física e Gameplay
--// ============================================================================

local BALL_INTERACTION_COOLDOWN = 2       -- Tempo entre interações do mesmo jogador com a bola
local TACKLE_COOLDOWN = 0.5               -- Tempo para reabilitar tackle após pegar bola
local BALL_OFFSET = CFrame.new(0, -BALL_INSTANCE.Size.Y / 2, BALL_INSTANCE.Size.Z / 2)
local RELEASE_OFFSET = CFrame.new(0, 0, BALL_INSTANCE.Size.Y / 2)
local DEFAULT_BALL_TIMER = 5              -- Tempo padrào de posse antes de violação
local DRAG_CONSTANT = SharedAttributes:GetKDrag()  -- Coeficiente de arrasto
local POWER_MULTIPLIER = 170              -- Multiplicador base de força de arremesso
local VERTICAL_AMPLIFIER = Vector3.new(0, 0.0375, 0)  -- Componente vertical do arremesso
local SAVE_FACTOR = 0.5                   -- Fator de redução de velocidade no save
local VERTICAL_SAVE_LINEAR = 30           -- Força vertical aplicada no save
local THROW_BUFF = 1.5                    -- Buff base de arremesso

--// ============================================================================
--// SETOR: Estado Global (Rastreamento de Bolas)
--// ============================================================================

-- Conexões de eventos por bola (cada bola tem seus próprios listeners)
local ballConnections = {}

-- Cooldown de interação por jogador por bola
local ballPlayersCooldown = {}

-- Motor6D de posse por bola
local ballMotors6D = {}

-- Cooldown de interação com GLT (linha de gol)
local gltInteractionCooldown = {}

-- Posições dos jogadores (para tracking)
local playersPositions = {}

-- Bolas ativas no jogo
local activeBalls = {}

-- Rastreamento de posição para Anti-Stuck
local ballPositionsTrack = {}

--// ============================================================================
--// SETOR: Loop Principal de Física (Stepped)
--// ============================================================================

--[[
	Loop central que processa todas as bolas a cada frame.
	Responsável por:
	- Cálculo de força de arrasto (drag)
	- Detecção de bola travada (Anti-Stuck)
	- Resgate de bola do void (Anti-Void)
]]
RunService.Stepped:Connect(function(deltaTime)
	local now = tick()
	for ABHBall, connections in ballConnections do
		if ABHBall:IsDescendantOf(BALLS_FOLDER) then
			-- Raposa: Tracker de movimento para Anti-Stuck
			local track = ballPositionsTrack[ABHBall]
			if not track then
				track = {lastPos = ABHBall.Position, lastTime = now}
				ballPositionsTrack[ABHBall] = track
			end

			-- Verifica se a bola está se movendo
			if (ABHBall.Position - track.lastPos).Magnitude > 0.1 then
				track.lastPos = ABHBall.Position
				track.lastTime = now
			elseif not ABHBall.Anchored and now - track.lastTime > 15 then
				-- Bola imóvel por 15 segundos: resetar para o meio do campo
				ABHBall.Position = Vector3.new(0, 10, 0)
				ABHBall.AssemblyLinearVelocity = Vector3.zero
				track.lastTime = now
			end

			-- Raposa: Anti-Void (bola caiu do mapa)
			if ABHBall.Position.Y < -10 then
				local lastThrower = ABHBall.Information.LastThrow.Value
				if lastThrower and lastThrower.Character and lastThrower.Character:FindFirstChild("Head") then
					ABHBall.Position = lastThrower.Character.Head.Position + Vector3.new(0, 20, 0)
				else
					ABHBall.Position += Vector3.new(0, 20, 0)
				end

				ABHBall.AssemblyLinearVelocity = Vector3.zero
				ABHBall.AssemblyAngularVelocity = Vector3.zero
				ABHBall.CanCollide = true
			end

			-- Cálculo de força de arrasto (drag) - aplicada horizontalmente
			local velocity = ABHBall.AssemblyLinearVelocity
			local appliedForce = -(velocity * DRAG_CONSTANT)
			appliedForce *= Vector3.new(1, 0, 1)  -- Remove componente Y
			ABHBall.ResistanceForce.Force = appliedForce
		end
	end
end)

--// ============================================================================
--// SETOR: Documentação de Conexões
--// ============================================================================

--[[
	Referência de índices de conexào por bola:
	ballConnections[ABHBall][1] = Collision (mudança de posse)
	ballConnections[ABHBall][2] = Ball touch (toque na bola)
	ballConnections[ABHBall][3] = Ball timer (contagem de tempo)
	ballConnections[ABHBall][4] = Unused (anteriormente Air Resistance)
	ballConnections[ABHBall][5] = Ball velocity reducer (redução ao tocar campo)
]]

--// ============================================================================
--// SETOR: Funções Auxiliares
--// ============================================================================

--- Inicializa as conexões de uma bola
function InitConnection(ABHBall: SharedTypes.ABHBallInstance)
	ballConnections[ABHBall] = table.create(5, Maid.new())
end

--- Verifica se dois jogadores são do mesmo time (Home ou Away)
-- Raposa: Função para detectar passes vs turnovers
local function IsSameTeam(p1: Player, p2: Player): boolean
	if not p1 or not p2 or not p1.Team or not p2.Team then return false end
	local t1 = p1.Team.Name
	local t2 = p2.Team.Name
	local t1Key = if t1:find("Home") then "Home" else "Away"
	local t2Key = if t2:find("Home") then "Home" else "Away"
	return t1Key == t2Key
end

--- Calcula o multiplicador de força baseado na marcação
-- Quanto mais oponentes próximos, mais força no arremesso
function throwPowerTransformation(x: number): number
	local int = math.floor(x)
	int = math.max(0, int)
	local t = THROW_BUFF - 0.6 * math.log(int + 1)
	return math.max(0.5, t)
end

--- Conta quantos oponentes estào próximos do jogador
function countOpponentsInRadius(blacklistPlayer: Player, center: Vector3): number
	local radiusSquared = 10 * 10
	local count = 0

	local presumedTeam = if blacklistPlayer.Team then blacklistPlayer.Team.Name else ""
	local opponents = {}
	if presumedTeam:find("Home") then
		opponents = Utils:MergeTables(AWAY_TEAM:GetPlayers(), AWAY_GK:GetPlayers())
	else
		opponents = Utils:MergeTables(HOME_TEAM:GetPlayers(), HOME_GK:GetPlayers())
	end

	for _, player in opponents do
		if player == blacklistPlayer then
			continue
		end
		local character = player.Character
		if character then
			local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if humanoidRootPart then
				local offset = humanoidRootPart.Position - center
				local distanceSquared = offset:Dot(offset)
				if distanceSquared <= radiusSquared then
					count += 1
				end
			end
		end
	end

	return count
end

--// ============================================================================
--// SETOR: Handlers de Eventos da Bola
--// ============================================================================

--- Handler de colisão: gerencia quando a bola muda de posse
function HandleCollision(ABHBall: SharedTypes.ABHBallInstance) 
	if not ballConnections[ABHBall] then
		return
	end

	local resistanceForce = ABHBall.ResistanceForce
	local playerOnBall = ABHBall.Information.CurrentPlayerOnBall	

	ballConnections[ABHBall][1]:GiveTask(playerOnBall:GetPropertyChangedSignal("Value"):Connect(function()
		if not playerOnBall.Value then
			-- Bola solta: habilita força de arrasto
			resistanceForce.Enabled = true
			-- Restaura CanCollide imediatamente para evitar atravessar objetos
			task.spawn(function()
				local originalCanCollide = ABHBall:GetAttribute("OriginalCanCollide")
				if originalCanCollide ~= nil then
					pcall(function() ABHBall.CanCollide = originalCanCollide end)
					ABHBall:SetAttribute("OriginalCanCollide", nil)
				else
					pcall(function() ABHBall.CanCollide = true end)
				end
			end)
		else 
			-- Bola em posse: desabilita força de arrasto
			resistanceForce.Enabled = false
		end
	end))
end

--- Aplica o Motor6D que conecta a bola à mão do jogador
function ApplyBallWeld(ABHBall: SharedTypes.ABHBallInstance, player: Player)
	local character = player.Character :: Model
	local currentHand = player:GetAttribute("CurrentHand")

	-- Determina qual mão usar (L = esquerda, R = direita)
	local presumedHand: BasePart
	if currentHand == "L" then
		presumedHand = character:FindFirstChild("Left Arm") :: BasePart
	else
		presumedHand = character:FindFirstChild("Right Arm") :: BasePart
	end

	-- Remove Motor6D existente se houver
	local existingMotor6D = ballMotors6D[ABHBall]
	if existingMotor6D then
		existingMotor6D:Destroy()
	end

	-- Cria novo Motor6D
	local motor6D = Instance.new("Motor6D")
	motor6D.Name = "BallOwnership"
	motor6D.Part0 = presumedHand
	motor6D.Part1 = ABHBall
	motor6D.C0 = BALL_OFFSET
	motor6D.Parent = character

	ballMotors6D[ABHBall] = motor6D

	-- Atualiza cor da trilha para cor do time
	ABHBall.Trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, player.TeamColor.Color),
		ColorSequenceKeypoint.new(1, player.TeamColor.Color)
	})

	-- Registra cooldown de interação
	ballPlayersCooldown[ABHBall][player.UserId] = os.clock()

	-- Salva estado original de CanCollide para restaurar depois
	if not ABHBall:GetAttribute("OriginalCanCollide") then
		ABHBall:SetAttribute("OriginalCanCollide", ABHBall.CanCollide)
	end
	ABHBall.CanCollide = false
end

--// ============================================================================
--// SETOR: Handler de Toque na Bola (Pegar Bola)
--// ============================================================================

--- Handler principal de toque: processa quando um jogador toca a bola
function HandleBallTouch(ABHBall: SharedTypes.ABHBallInstance)
	if not ballConnections[ABHBall] then
		return
	end

	local informationFolder = ABHBall.Information
	local lastThrow = informationFolder.LastThrow

	ballConnections[ABHBall][2]:GiveTask(ABHBall.Touched:Connect(function(otherPart)		
		-- Ignora toque em redes (para bola não atravessar)
		if otherPart.Name == "Nets" then
			ABHBall.AssemblyLinearVelocity = Vector3.zero
			ABHBall.AssemblyAngularVelocity = Vector3.zero
			return
		end

		-- Verifica se foi um jogador que tocou
		local player = Players:GetPlayerFromCharacter(otherPart.Parent :: Model)
		if not player then
			return
		end

		-- Verifica ping máximo permitido
		local playerPing = (player.leaderstats.Ping :: NumberValue).Value
		if playerPing >= SharedAttributes:MaxPing() then
			return
		end

		-- Raposa: não permite pegar bola se partida estiver pausada
		if MATCH_PAUSED.Value then
			return
		end

		ABHBall.Anchored = false

		-- Validações de estado da bola
		if not informationFolder.CanTackle.Value then
			return
		end
		if informationFolder.CurrentPlayerOnBall.Value then
			return
		end
		if ABHBall:GetAttribute("Saved") == true then
			return
		end

		-- Validações do jogador
		local character = player.Character
		if not character then
			return
		end

		local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
		if not humanoid or humanoid.Health <= 0 then
			return
		end

		if character:FindFirstChild("BallOwnership") then 
			return
		end

		-- Verifica ForceField (proteção de cobrança)
		local forceField = ABHBall:FindFirstChild("ForceField")
		if forceField then
			local takerUserId = forceField:GetAttribute("TakerUserId")
			local ignore = forceField:GetAttribute("Ignore")
			if takerUserId and not ignore then
				if takerUserId ~= player.UserId then
					return
				end
			end
		end

		-- Verifica cooldown de interação
		local playerCooldown = ballPlayersCooldown[ABHBall][player.UserId] :: number?
		if playerCooldown then
			local lastInteraction = os.clock() - playerCooldown
			if lastInteraction <= BALL_INTERACTION_COOLDOWN then
				return
			end
		end

		-- Raposa: Detecção de passback (recuo para goleiro)
		if MATCH_VALUE.Value then
			for i, v in HOME_AREA:GetTouchingParts() do
				local p = Players:GetPlayerFromCharacter(v.Parent)
				if p and p.UserId == player.UserId then
					if lastThrow and lastThrow ~= informationFolder.CurrentPlayerOnBall.Value then
						if (player.Team and player.Team.Name == "-Home Goalkeeper" and lastThrow.Value and lastThrow.Value.Team and lastThrow.Value.Team.Name:find("Home")) then
							for u, w in Teams.Officials:GetPlayers() do
								LEAGUE_EVENT:FireClient(w, "POSSIBLE_PASSBACK", true)
							end
							break
						end
					end
				end
			end

			for i, v in AWAY_AREA:GetTouchingParts() do
				local p = Players:GetPlayerFromCharacter(v.Parent)
				if p and p.UserId == player.UserId then
					if lastThrow and lastThrow ~= informationFolder.CurrentPlayerOnBall.Value then
						if (player.Team and player.Team.Name == "-Away Goalkeeper" and lastThrow.Value and lastThrow.Value.Team and lastThrow.Value.Team.Name:find("Away")) then
							for u, w in Teams.Officials:GetPlayers() do
								LEAGUE_EVENT:FireClient(w, "POSSIBLE_PASSBACK", false)
							end
							break
						end
					end
				end
			end
		end

		-- Remove força vertical existente
		local vectorForce = ABHBall:FindFirstChild("VerticalForce") :: VectorForce
		if vectorForce then
			vectorForce:Destroy()
		end
		informationFolder.CanTackle.Value = false

		-- Raposa: Registro de estatísticas de passe
		local lastThrowUserId = ABHBall:GetAttribute("LastThrowUserId") or (informationFolder.LastThrow.Value and informationFolder.LastThrow.Value.UserId)
		local lastThrower = nil
		if lastThrowUserId then
			lastThrower = Players:GetPlayerByUserId(lastThrowUserId)
		else
			lastThrower = informationFolder.LastThrow.Value
		end

		-- Verificação de tempo (evita atribuir passes antigos)
		local lastThrowTime = ABHBall:GetAttribute("LastThrowTime")
		if lastThrowTime and (os.time() - lastThrowTime) > 15 then
			lastThrower = nil
		end

		-- Registra passe completo ou turnover
		if lastThrower and lastThrower ~= player then
			if IsSameTeam(lastThrower, player) then
				GameStatistics.RecordEvent(lastThrower, "PassComplete")
			else
				GameStatistics.RecordEvent(lastThrower, "PassFailed")
				GameStatistics.RecordEvent(lastThrower, "Turnover")
			end
		end

		-- Goleiro pegando chute = save
		if player.Team and player.Team.Name:find("Goalkeeper") then
			local wasShot = ABHBall:GetAttribute("IsShot") or ABHBall:GetAttribute("IsSOG")
			if wasShot then
				ABHBall:SetAttribute("IsSOG", true)
				ABHBall:SetAttribute("Saved", true)
				GameStatistics.RecordEvent(player, "Save")
				local shooter = ABHBall.Information.LastThrow.Value :: Player?
				if shooter and shooter ~= player then
					GameStatistics.RecordEvent(shooter, "SavedShot")
				end
				task.delay(0.5, function()
					ABHBall:SetAttribute("Saved", false)
				end)
			end
		end

		-- Aplica posse da bola
		ABHBall.AssemblyLinearVelocity = Vector3.zero
		ABHBall.AssemblyAngularVelocity = Vector3.zero
		ApplyBallWeld(ABHBall, player)
		informationFolder.CurrentPlayerOnBall.Value = player

		-- Aguarda cooldown de tackle
		task.wait(TACKLE_COOLDOWN)
		if not ABHBall:IsDescendantOf(BALLS_FOLDER) then
			return
		end
		informationFolder.CanTackle.Value = true
	end))
end

--// ============================================================================
--// SETOR: Handler de Timer de Posse
--// ============================================================================

--- Gerencia o timer de posse e violações de tempo
function HandleBallTimer(ABHBall: SharedTypes.ABHBallInstance)
	local informationFolder = ABHBall.Information
	local currentPlayerOnBall = informationFolder.CurrentPlayerOnBall
	local lastPlayerOnBall = informationFolder.LastPlayerOnBall
	local lastThrow = informationFolder.LastThrow
	local thread: thread?

	ballConnections[ABHBall][3]:GiveTask(currentPlayerOnBall:GetPropertyChangedSignal("Value"):Connect(function()
		local oldPlayerOnBall = currentPlayerOnBall.Value

		-- Raposa: Atualiza tag de nome na bola
		if currentPlayerOnBall.Value then
			GameStatistics.RecordEvent(currentPlayerOnBall.Value, "PossessionStart")
			local tag = ABHBall:FindFirstChild("SpawnerTag")
			if tag and tag:FindFirstChildOfClass("TextLabel") then
				tag:FindFirstChildOfClass("TextLabel").Text = currentPlayerOnBall.Value.Name
			end
		else
			local tag = ABHBall:FindFirstChild("SpawnerTag")
			if tag and tag:FindFirstChildOfClass("TextLabel") then
				tag:FindFirstChildOfClass("TextLabel").Text = ""
			end
		end

		-- Limpa thread anterior
		if not currentPlayerOnBall.Value then 
			if thread ~= nil then
				coroutine.close(thread)
				thread = nil
			end
			return
		end

		if thread ~= nil then
			coroutine.close(thread)
		end

		-- Caso especial: jogador pegou a própria bola de volta (violação)
		if currentPlayerOnBall.Value == lastThrow.Value and lastPlayerOnBall.Value == lastThrow.Value then
			local lastPosition = ABHBall.Position
			ABHBall.Timer.Seconds.TextColor3 = Color3.fromRGB(255, 0, 0)
			ABHBall.Timer.Seconds.Text = tostring((currentPlayerOnBall.Value :: Instance).Name)
			ABHBall.CanTouch = false

			local playerInstance = currentPlayerOnBall.Value :: Player?
			if playerInstance then
				if playerInstance.Character then
					local ownership = (playerInstance.Character :: Model):FindFirstChild("BallOwnership")
					if ownership then
						ownership:Destroy()
					end
				end

				-- Raposa: aciona falta por violação
				local playerTeamName = playerInstance.Team.Name
				local isGK = playerTeamName:find("Goalkeeper")
				local isHome = playerTeamName:find("Home")

				if MATCH_VALUE.Value then
					ServerEvents.League:Fire("BALL_TIME_VIOLATION", playerInstance)
					if isGK then
						ServerEvents.League:Fire("PENALTY", not isHome, isHome)
					else
						ServerEvents.League:Fire("FREE_THROW", lastPosition, not isHome)
					end
					GameStatistics.RecordEvent(playerInstance, "Turnover")
				end
			end

			-- Destroi bola com efeito visual
			currentPlayerOnBall.Value = nil
			ABHBall.AssemblyLinearVelocity = Vector3.zero
			ABHBall.AssemblyAngularVelocity = Vector3.zero
			local vectorForce = ABHBall:FindFirstChild("VerticalForce")
			if vectorForce then
				vectorForce:Destroy()
			end

			ABHBall.Anchored = true
			ABHBall.CanCollide = false
			ABHBall.Material = Enum.Material.Neon

			if playerInstance then
				ABHBall.Color = playerInstance.TeamColor.Color
			else
				ABHBall.Color = Color3.fromRGB(255, 255, 255)
			end

			ABHBall.TextureID = ""
			Debris:AddItem(ABHBall, 3)
			return
		end

		-- Reseta timer para novo jogador
		if currentPlayerOnBall.Value then
			ABHBall.Timer.Seconds.TextColor3 = Color3.fromRGB(255, 255, 255)
			informationFolder.Timer.Value = DEFAULT_BALL_TIMER
			ABHBall.Timer.Seconds.Text = string.format("%.1f", informationFolder.Timer.Value)
		end

		-- Thread de contagem regressiva
		thread = coroutine.create(function()		
			while currentPlayerOnBall.Value and ABHBall:IsDescendantOf(BALLS_FOLDER) do
				task.wait(0.1)

				-- Raposa: registra tempo de posse
				if currentPlayerOnBall.Value then
					GameStatistics.RecordEvent(currentPlayerOnBall.Value, "Possession", 0.1)
				end

				local playerOnBall = currentPlayerOnBall.Value
				local isGK = playerOnBall and playerOnBall.Team.Name:find("Goalkeeper")
				local isImmune = ABHBall:FindFirstChild("ForceField") or ABHBall:FindFirstChild("RefereeImmunity") or ABHBall:GetAttribute("Saved") == true

				-- Goleiro conta timer mesmo com imunidade
				if BALL_TIMER.Value and (not isImmune or isGK) then
					if informationFolder.Timer.Value <= 0 then
						break
					end

					if oldPlayerOnBall ~= currentPlayerOnBall.Value then
						break
					end

					informationFolder.Timer.Value -= 0.1
					ABHBall.Timer.Seconds.Text = string.format("%.1f", informationFolder.Timer.Value)
				end
			end

			if not ABHBall:IsDescendantOf(BALLS_FOLDER) then
				return
			end

			-- Timer expirou: violação de tempo
			if informationFolder.Timer.Value <= 0 and currentPlayerOnBall.Value then
				local lastPosition = ABHBall.Position

				ABHBall.Timer.Seconds.TextColor3 = Color3.fromRGB(255, 0, 0)
				ABHBall.Timer.Seconds.Text = tostring((currentPlayerOnBall.Value :: Instance).Name)
				ABHBall.CanTouch = false

				local playerInstance = currentPlayerOnBall.Value :: Player
				if playerInstance.Character then
					local ownership = (playerInstance.Character :: Model):FindFirstChild("BallOwnership")
					if ownership then
						ownership:Destroy()
					end
				end

				-- Raposa: Aciona infração por tempo expirado
				local playerTeamName = playerInstance.Team.Name
				local isGK = playerTeamName:find("Goalkeeper")
				local isHome = playerTeamName:find("Home")

				if MATCH_VALUE.Value then
					ServerEvents.League:Fire("BALL_TIME_VIOLATION", playerInstance)
					if isGK then
						ServerEvents.League:Fire("PENALTY", not isHome, isHome)
					else
						ServerEvents.League:Fire("FREE_THROW", lastPosition, not isHome)
					end
					GameStatistics.RecordEvent(playerInstance, "Turnover")
				end

				-- Efeito visual de violação
				currentPlayerOnBall.Value = nil
				ABHBall.AssemblyLinearVelocity = Vector3.zero
				ABHBall.AssemblyAngularVelocity = Vector3.zero
				local vectorForce = ABHBall:FindFirstChild("VerticalForce")
				if vectorForce then
					vectorForce:Destroy()
				end

				ABHBall.Anchored = true
				ABHBall.CanCollide = false
				ABHBall.Material = Enum.Material.Neon
				ABHBall.Color = playerInstance.TeamColor.Color
				ABHBall.TextureID = ""
				Debris:AddItem(ABHBall, 3)
			end
		end)

		coroutine.resume(thread)
	end))
end

--// ============================================================================
--// SETOR: Handler de Resistência do Ar (Deprecated)
--// ============================================================================

--- Lógica movida para loop central Stepped para performance
function HandleBallAirResistance(ABHBall: SharedTypes.ABHBallInstance)
	-- Logic moved to central Stepped loop for performance
end

--// ============================================================================
--// SETOR: Cálculo de Força de Arremesso
--// ============================================================================

--- Calcula a posição e velocidade do arremesso
function CalculatePower(startingCFrame: CFrame, directionData: SharedTypes.DirectionData, power: number, player: Player)
	local calculatedPower = math.sqrt(power / 100) * POWER_MULTIPLIER
	local hrp = player.Character.HumanoidRootPart
	local fixedPower = FixedPower(directionData.mouseDirection, directionData.mousePosition, directionData.humanoidRootPartDirection, calculatedPower, hrp.Position, player)
	calculatedPower = fixedPower

	local direction = VectorLib:VectorLibToVector3(directionData.mouseDirection)

	local releasePosition = startingCFrame * RELEASE_OFFSET
	local velocity = (direction + VERTICAL_AMPLIFIER) * calculatedPower

	return {
		releasePosition, velocity
	}
end

--// ============================================================================
--// SETOR: Funções Públicas do Módulo
--// ============================================================================

--- Transforma bola em "fantasma" (efeito visual de destruição)
function ABHBall:Ghostball(ballInstance: SharedTypes.ABHBallInstance)
	local ghost = ballInstance:Clone()
	ballInstance:Destroy()

	ghost.CanTouch = false
	ghost.AssemblyLinearVelocity = Vector3.zero
	ghost.AssemblyAngularVelocity = Vector3.zero
	ghost.Anchored = true
	ghost.Timer:Destroy()
	ghost.SpecialMesh:Destroy()
	ghost.TextureID = ""
	ghost.BrickColor = BrickColor.White()
	ghost.Material = Enum.Material.Neon
	ghost.Parent = workspace
	Debris:AddItem(ghost, 3)
end

--- Aplica força vertical para simular arco no arremesso
function ABHBall:ApplyVerticalForce(ABHBall: SharedTypes.ABHBallInstance)
	local forceMaid = Maid.new()
	local yForce = ABHBall:GetMass() * workspace.Gravity * 0.75

	local existingForce = ABHBall:FindFirstChild("VerticalForce")
	if existingForce then
		return
	end

	local vectorForce = Instance.new("VectorForce")
	vectorForce.Name = "VerticalForce"
	local baseBallForce = vector.create(0, yForce, 0)
	vectorForce.Force = baseBallForce
	vectorForce.RelativeTo = Enum.ActuatorRelativeTo.World
	vectorForce.Attachment0 = ABHBall.Middle
	vectorForce.ApplyAtCenterOfMass = true
	vectorForce.Parent = ABHBall

	-- Remove força quando bola toca algo
	task.delay(0.125, function()
		forceMaid:GiveTask(ABHBall.Touched:Connect(function(touchingPart)
			-- Ignora superfícies de jogo
			if touchingPart.Name == "RealField" then return end
			if touchingPart.Name == "FieldGrass" then return end
			if touchingPart.Name == "ABHBall" then return end
			if touchingPart.Name == "ForceField" then return end
			if touchingPart.Name == "Area" or touchingPart.Name == "HomeArea" or touchingPart.Name == "AwayArea" then return end
			if touchingPart.Name == "Grass" then return end
			if touchingPart.Name == "Barrier" then return end
			if Players:GetPlayerFromCharacter(touchingPart.Parent :: Model) then return end
			if touchingPart.Name == "Handle" then return end

			vectorForce:Destroy()
			forceMaid:Destroy()
		end))
	end)
end

--- Reduz velocidade quando bola toca o campo
function BallVelocityReducer(ABHBall: SharedTypes.ABHBallInstance)
	ballConnections[ABHBall][5]:GiveTask(ABHBall.Touched:Connect(function(child)
		if not ABHBall:IsDescendantOf(workspace) then
			return
		end
		if child.Name ~= "RealField" then
			return
		end
		if ABHBall.Information.CurrentPlayerOnBall.Value ~= nil then
			return
		end

		ABHBall.AssemblyLinearVelocity *= 0.97
	end))
end

--// ============================================================================
--// SETOR: Criação de Bola
--// ============================================================================

--- Cria uma nova bola no jogo
function ABHBall:Create(cframe: CFrame, spawner: Player?)	
	local protectConnection = Janitor.new()

	local instance = BALL_INSTANCE:Clone()
	instance.Name = HttpService:GenerateGUID()
	instance.CFrame = cframe

	-- Raposa: Criar/Ajustar Tag de Nome (SpawnerTag) e Timer
	local nameTag = instance:FindFirstChild("SpawnerTag")
	if not nameTag then
		nameTag = Instance.new("BillboardGui")
		nameTag.Name = "SpawnerTag"
		nameTag.Size = UDim2.new(0, 100, 0, 20)
		nameTag.AlwaysOnTop = true

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0
		label.Font = Enum.Font.GothamBold
		label.TextSize = 12
		label.Parent = nameTag

		nameTag.Parent = instance
	end

	nameTag.StudsOffset = Vector3.new(0, 1.2, 0)
	nameTag.MaxDistance = 50
	local label = nameTag:FindFirstChildOfClass("TextLabel")
	if label then
		label.Text = if spawner then spawner.Name else ""
	end

	if instance:FindFirstChild("Timer") then
		instance.Timer.StudsOffset = Vector3.new(0, 2.0, 0)
		instance.Timer.MaxDistance = 50
	end

	-- Inicializa estados
	playersPositions[instance] = {}
	ballPlayersCooldown[instance] = {}
	ballMotors6D[instance] = nil
	instance:SetAttribute("Saved", false)
	instance.Information.CanTackle.Value = true
	instance.CanCollide = true

	-- Garante que o Timer existe
	if not instance.Information:FindFirstChild("Timer") then
		local timerValue = Instance.new("NumberValue")
		timerValue.Name = "Timer"
		timerValue.Value = DEFAULT_BALL_TIMER
		timerValue.Parent = instance.Information
	end

	-- Inicializa conexões
	coroutine.wrap(InitConnection)(instance)
	coroutine.wrap(HandleCollision)(instance)
	coroutine.wrap(HandleBallTouch)(instance)
	coroutine.wrap(HandleBallAirResistance)(instance)
	coroutine.wrap(BallVelocityReducer)(instance)
	task.spawn(HandleBallTimer, instance)

	instance.Information.Timer.Value = DEFAULT_BALL_TIMER

	-- Cleanup ao destruir
	instance.Destroying:Connect(function()
		for _, connection in ballConnections[instance] do
			connection:DoCleaning()
		end

		table.clear(playersPositions[instance])
		table.clear(ballPlayersCooldown[instance])
		if ballMotors6D[instance] then
			ballMotors6D[instance]:Destroy()
			ballMotors6D[instance] = nil
		end

		gltInteractionCooldown[instance] = nil
		ballConnections[instance] = nil
	end)

	-- ForceField: proteção de cobrança
	local forceField = instance.ForceField
	forceField:SetAttribute("TakerUserId", 0)
	protectConnection:LinkToInstance(forceField)
	protectConnection:Add(forceField:GetAttributeChangedSignal("TakerUserId"):Connect(function()
		local userId = forceField:GetAttribute("TakerUserId")
		if not userId or userId == 0 then
			return
		end

		local player = Players:GetPlayerByUserId(userId)
		local character = player and player.Character
		local primaryPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not primaryPart then
			return
		end

		-- Raposa: Anular velocidade ao tocar no ForceField
		primaryPart.AssemblyLinearVelocity = Vector3.zero
		primaryPart.AssemblyAngularVelocity = Vector3.zero

		local linearVelocity = Instance.new("LinearVelocity")
		linearVelocity.Attachment0 = primaryPart:FindFirstChild("RootAttachment") or Instance.new("Attachment", primaryPart)
		linearVelocity.MaxForce = math.huge
		linearVelocity.VectorVelocity = vector.zero
		linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
		linearVelocity.Enabled = false
		linearVelocity.Parent = primaryPart

		protectConnection:Add(linearVelocity, "Destroy")

		-- Raposa: Travar movimento do cobrador
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local oldJumpPower = humanoid.JumpPower
			local oldJumpHeight = humanoid.JumpHeight
			local oldWalkSpeed = humanoid.WalkSpeed
			local currentlyApplied = false

			local function update()
				local player = Players:GetPlayerFromCharacter(character)
				local hasBall = character:FindFirstChild("BallOwnership") ~= nil
				local isSwitching = player and player:GetAttribute("SwitchingHands") == true

				local shouldApply = hasBall and not isSwitching

				if shouldApply then
					if not currentlyApplied then
						currentlyApplied = true
						oldJumpPower = humanoid.JumpPower
						oldJumpHeight = humanoid.JumpHeight
						oldWalkSpeed = humanoid.WalkSpeed

						humanoid.JumpPower = 0
						humanoid.JumpHeight = 0
						humanoid.WalkSpeed = 0
						linearVelocity.Enabled = true
					end
				else
					if currentlyApplied then
						currentlyApplied = false
						humanoid.JumpPower = oldJumpPower
						humanoid.JumpHeight = oldJumpHeight
						humanoid.WalkSpeed = oldWalkSpeed
						linearVelocity.Enabled = false
					end
				end
			end

			protectConnection:Add(character.ChildAdded:Connect(function(child)
				if child.Name == "BallOwnership" then update() end
			end), "Disconnect")
			protectConnection:Add(character.ChildRemoved:Connect(function(child)
				if child.Name == "BallOwnership" then update() end
			end), "Disconnect")

			local player = Players:GetPlayerFromCharacter(character)
			if player then
				protectConnection:Add(player:GetAttributeChangedSignal("SwitchingHands"):Connect(update), "Disconnect")
			end

			update()

			protectConnection:Add(function()
				if currentlyApplied then
					if humanoid and humanoid.Parent then
						humanoid.JumpPower = oldJumpPower
						humanoid.JumpHeight = oldJumpHeight
						humanoid.WalkSpeed = oldWalkSpeed
					end
				end
			end)
		end
	end), "Disconnect")

	-- Bola pausada se partida pausada
	if MATCH_PAUSED.Value then
		instance.Anchored = true
		pcall(function() instance.CanCollide = false end)
		pcall(function() instance.CanTouch = false end)
		instance:SetAttribute("Paused", true)
	end

	instance.Parent = BALLS_FOLDER
	return instance
end

--// ============================================================================
--// SETOR: Arremesso de Bola
--// ============================================================================

--- Executa o arremesso da bola
function ABHBall:Throw(player: Player, instance: SharedTypes.ABHBallInstance, directionData: SharedTypes.DirectionData, power: number)
	local data = CalculatePower(instance.CFrame, directionData, power, player)
	local releasePosition = data[1] :: CFrame
	local velocity = data[2] :: Vector3

	-- Compensação de lag: avança posição inicial baseado no ping
	local playerPing = 0
	pcall(function()
		playerPing = player.leaderstats.Ping.Value / 1000
	end)

	local leadTime = math.min(playerPing, 0.15) 
	local advancedPosition = releasePosition.Position + (velocity * leadTime)

	-- Só avança se não há obstáculo
	local leadRay = workspace:Raycast(releasePosition.Position, velocity * leadTime, RaycastParams.new())
	if not leadRay then
		releasePosition = releasePosition - releasePosition.Position + advancedPosition
	end

	-- Remove Motor6D de posse
	if ballMotors6D[instance] then
		ballMotors6D[instance]:Destroy()
		ballMotors6D[instance] = nil
	end

	local character = player.Character
	if character then
		local ballOwnership = character:FindFirstChild("BallOwnership")
		if ballOwnership then
			ballOwnership:Destroy()
		end
	end

	-- Remove proteções
	if instance:FindFirstChild("RefereeImmunity") then
		(instance.RefereeImmunity :: Instance):Destroy()
	end
	if instance:FindFirstChild("ForceField") then
		(instance.ForceField):Destroy()
	end

	-- Notifica watchdog da liga
	ServerEvents.League:Fire("PLAYER_THROW", player)

	-- Raposa: Todo arremesso conta como tentativa de passe
	GameStatistics.RecordEvent(player, "PassAttempt")

	-- Detecção de chute ao gol
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {HOME_GLT, AWAY_GLT}
	raycastParams.FilterType = Enum.RaycastFilterType.Include

	local result = workspace:Raycast(releasePosition.Position, vector.normalize(directionData.mouseDirection) * 77, raycastParams)
	local multiplier = 1

	-- Verifica se arremesso mira no gol adversário
	local isAimedAtGoal = false
	local playerTeamName = (player.Team and player.Team.Name) or ""
	local goalPos = nil
	if playerTeamName:find("Home") then
		goalPos = AWAY_GLT and AWAY_GLT.Position or nil
	else
		goalPos = HOME_GLT and HOME_GLT.Position or nil
	end
	if goalPos then
		local aimDir = vector.normalize(directionData.mouseDirection)
		local toGoal = goalPos - releasePosition.Position
		if toGoal.Magnitude > 0 then
			local toGoalDir = toGoal.Unit
			local dot = aimDir:Dot(toGoalDir)
			if dot >= 0.6 then
				isAimedAtGoal = true
			end
		end
	end

	-- Classifica arremesso
	if result then
		-- Trajetória cruza o gol (Shot on Goal)
		instance:SetAttribute("IsSOG", true)
		instance:SetAttribute("IsShot", true)
		local markingQtd = countOpponentsInRadius(player, character.HumanoidRootPart.Position)
		multiplier = throwPowerTransformation(markingQtd)
	elseif isAimedAtGoal then
		-- Mirou no gol mas não cruzou (chute pra fora)
		instance:SetAttribute("IsSOG", false)
		instance:SetAttribute("IsShot", true)
	else
		-- Passe normal
		instance:SetAttribute("IsSOG", false)
		instance:SetAttribute("IsShot", false)
	end

	instance.CFrame = releasePosition

	-- Correção: Garantir que bola não spawne embaixo do chào
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {BALLS_FOLDER, player.Character}
	local rayResult = workspace:Raycast(releasePosition.Position + Vector3.new(0, 2, 0), Vector3.new(0, -4, 0), rayParams)
	if rayResult then
		local floorHeight = rayResult.Position.Y
		local ballRadius = instance.Size.Y / 2
		if instance.Position.Y < floorHeight + ballRadius then
			instance.CFrame = (releasePosition - releasePosition.Position) + Vector3.new(releasePosition.Position.X, floorHeight + ballRadius + 0.05, releasePosition.Position.Z)
		end
	end

	-- Restaura CanCollide
	local originalCanCollide = instance:GetAttribute("OriginalCanCollide")
	if originalCanCollide ~= nil then
		instance.CanCollide = originalCanCollide
		instance:SetAttribute("OriginalCanCollide", nil)
	else
		instance.CanCollide = true
	end

	ABHBall:ApplyVerticalForce(instance)

	-- Atualiza informações de último arremesso
	ballPlayersCooldown[instance][player.UserId] = os.clock()
	if instance.Information.LastThrow.Value ~= instance.Information.LastLastThrow.Value then
		instance.Information.LastLastThrow.Value = instance.Information.LastThrow.Value
	end
	instance.Information.LastThrow.Value = player

	-- Persiste ID do último arremessador
	pcall(function()
		instance:SetAttribute("LastThrowUserId", player.UserId)
		instance:SetAttribute("LastThrowTime", os.time())
	end)

	instance.Information.LastPlayerOnBall.Value = instance.Information.CurrentPlayerOnBall.Value
	instance.Information.CurrentPlayerOnBall.Value = nil
	instance.AssemblyAngularVelocity = Vector3.zero
	instance.AssemblyLinearVelocity = velocity * multiplier
end

--// ============================================================================
--// SETOR: Utilitários de Bola
--// ============================================================================

--- Remove todas as bolas do jogo
function ABHBall:DoCleaning()
	for _, instance in BALLS_FOLDER:GetChildren() do
		instance:Destroy()
	end
end

--- Obtém cooldown de interação com GLT
function ABHBall:GetGLTCooldown(instance: SharedTypes.ABHBallInstance)
	return gltInteractionCooldown[instance]
end

--- Define cooldown de interação com GLT
function ABHBall:SetGLTCooldown(instance: SharedTypes.ABHBallInstance, state: boolean)
	gltInteractionCooldown[instance] = state
end

--// ============================================================================
--// SETOR: Save de Goleiro
--// ============================================================================

--- Processa save do goleiro (defesa manual)
function ABHBall:HandleGoalkeeperSave(instance: SharedTypes.ABHBallInstance, cframe: CFrame, player: Player)
	if not instance:FindFirstChild("Information") then
		return
	end
	if instance.Information.CurrentPlayerOnBall.Value then
		return
	end

	if instance:GetAttribute("Saved") == true then
		return
	end

	-- Raposa: Registra save nas estatísticas
	local wasShot = instance:GetAttribute("IsShot") or instance:GetAttribute("IsSOG")
	if wasShot then
		instance:SetAttribute("IsSOG", true)
		instance:SetAttribute("Saved", true)
		GameStatistics.RecordEvent(player, "Save")
		local shooter = instance.Information.LastThrow.Value :: Player?
		if shooter and shooter ~= player then
			GameStatistics.RecordEvent(shooter, "SavedShot")
			GameStatistics.RecordEvent(shooter, "SOG")
		end
	end
	ABHBall:SetGLTCooldown(instance, true)

	-- Remove força vertical existente
	local vectorForce = instance:FindFirstChild("VectorForce")
	if vectorForce then
		vectorForce:Destroy()
	end

	-- Calcula nova trajetória do save
	local velocity = instance.AssemblyLinearVelocity :: Vector3
	local multiplier = math.max(instance.AssemblyLinearVelocity.Magnitude, 30)
	local ballVelocity = cframe.LookVector.Unit * multiplier

	local releasePosition = cframe * RELEASE_OFFSET
	local velocity = (ballVelocity * SAVE_FACTOR) + Vector3.new(0, VERTICAL_SAVE_LINEAR, 0)
	ABHBall:ApplyVerticalForce(instance)
	instance.CFrame = releasePosition
	instance.AssemblyAngularVelocity = Vector3.new()
	instance.AssemblyLinearVelocity = velocity
	instance.Information.CurrentPlayerOnBall.Value = nil
	if instance.Information.LastThrow.Value ~= instance.Information.LastLastThrow.Value then
		instance.Information.LastLastThrow.Value = instance.Information.LastThrow.Value
	end
	instance.Information.LastThrow.Value = player

	task.wait(0.5)
	instance:SetAttribute("Saved", false)
	ABHBall:SetGLTCooldown(instance, false)
end

--// ============================================================================
--// SETOR: Tackle (Roubo de Bola)
--// ============================================================================

--- Processa tackle de um jogador
function ABHBall:HandleTackle(instance: SharedTypes.ABHBallInstance, player: Player)	
	-- Raposa: não permite tackle se partida pausada
	if MATCH_PAUSED.Value then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	-- Verifica cooldown
	local playerCooldown = ballPlayersCooldown[instance][player.UserId] :: number?
	if playerCooldown then
		local lastInteraction = os.clock() - playerCooldown
		if lastInteraction <= BALL_INTERACTION_COOLDOWN then
			return
		end
	end

	-- não pode tacklear se já tem bola
	local ballOwnership = character:FindFirstChild("BallOwnership") :: Motor6D
	if ballOwnership then
		return
	end

	-- Verifica se tackle está habilitado
	local canTackle = instance.Information.CanTackle.Value 
	if not canTackle then
		return
	end

	-- não pode tacklear bola protegida
	if instance:FindFirstChild("ForceField") then
		return
	end

	-- Verifica ping máximo
	local playerPing = (player.leaderstats.Ping :: NumberValue).Value
	if playerPing >= SharedAttributes:MaxPing() then
		return
	end

	-- Verifica ForceField de cobrança
	local forceField = instance:FindFirstChild("ForceField")
	if forceField then
		local isHome = forceField:GetAttribute("isHome")
		local team = (player.Team :: Team).Name

		if isHome and not team:find("Home") then
			return
		end
		if not isHome and team:find("Home") then
			return
		end
	end

	-- Executa tackle
	instance.Information.CanTackle.Value = false
	local vectorForce = instance:FindFirstChild("VerticalForce")
	if vectorForce then
		vectorForce:Destroy()
	end

	-- Remove posse anterior
	if ballMotors6D[instance] then
		ballMotors6D[instance]:Destroy()
		ballMotors6D[instance] = nil
	end

	local currentPlayer = instance.Information.CurrentPlayerOnBall.Value :: Player
	if currentPlayer then
		local cpCharacter = currentPlayer.Character
		if cpCharacter then
			local cpBallOwnership = cpCharacter:FindFirstChild("BallOwnership") :: Motor6D
			if cpBallOwnership then
				cpBallOwnership:Destroy()
			end
		end
	end

	instance.Information.LastPlayerOnBall.Value = currentPlayer

	-- Registra roubo se tomou de oponente
	if currentPlayer and currentPlayer ~= player then
		local currentTeam = (currentPlayer.Team and currentPlayer.Team.Name) or ""
		local playerTeam = (player.Team and player.Team.Name) or ""
		local tookFromOpposingTeam = false
		if (currentTeam:find("Home") and not playerTeam:find("Home")) or (currentTeam:find("Away") and not playerTeam:find("Away")) then
			tookFromOpposingTeam = true
		end
		if tookFromOpposingTeam then
			GameStatistics.RecordEvent(player, "Steal")
			GameStatistics.RecordEvent(currentPlayer, "Turnover")
		end
	end

	-- Aplica nova posse
	instance.AssemblyLinearVelocity = Vector3.zero
	instance.AssemblyAngularVelocity = Vector3.zero
	ApplyBallWeld(instance, player)
	instance.Information.CurrentPlayerOnBall.Value = player

	task.wait(0.5)

	instance.Information.CanTackle.Value = true
end

--// ============================================================================
--// SETOR: Retorno do Módulo
--// ============================================================================

return ABHBall
