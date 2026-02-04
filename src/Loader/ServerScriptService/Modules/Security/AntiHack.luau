--[[
	================================================================================
	MÓDULO: AntiHack (Sistema de Detecção de Hacks)
	================================================================================
	
	Descrição:
		Sistema centralizado de anti-hack que detecta e reporta atividades
		suspeitas para os Officials (árbitros/admins).
		
		Funcionalidades:
		- Rate limiting de eventos
		- Detecção de speed hack
		- Detecção de teleport
		- Detecção de hitbox modification
		- Sistema de alertas para Officials
		- Histórico de violações
	
	Autor: Sistema ABH
	================================================================================
]]

--// ============================================================================
--// SETOR: Definição do Módulo
--// ============================================================================

local AntiHack = {}

--// ============================================================================
--// SETOR: Serviços do Roblox
--// ============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

--// ============================================================================
--// SETOR: Dependências
--// ============================================================================

local SharedAttributes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Implementation"):WaitForChild("SharedAttributes"))

--// ============================================================================
--// SETOR: Eventos de Rede
--// ============================================================================

local NETWORK_FOLDER = ReplicatedStorage:WaitForChild("Network") :: Folder
local LEAGUE_EVENT = NETWORK_FOLDER:WaitForChild("LeagueEvent") :: RemoteEvent

--// ============================================================================
--// SETOR: Configuração de Rate Limiting
--// ============================================================================

local RATE_LIMITS = {
	SpawnRequest = { maxPerMinute = 100, cooldown = 1 },
	ThrowEvent = { maxPerMinute = 100, cooldown = 1 },
	SwitchHands = { maxPerMinute = 100, cooldown = 1 },
	Goalkeeper = { maxPerMinute = 100, cooldown = 1 },
	Tackling = { maxPerMinute = 100, cooldown = 1 },
	BallEvents = { maxPerMinute = 100, cooldown = 1 },
}

--// ============================================================================
--// SETOR: Configuração de Detecção
--// ============================================================================

-- Velocidade máxima permitida (SprintSpeed + margem)
local MAX_WALKSPEED = 28

-- Distância máxima de teleporte por frame (studs)
local MAX_TELEPORT_DISTANCE = 100

-- Velocidade máxima da bola (studs/s)
local MAX_BALL_SPEED = 400

-- Tamanho válido da hitbox do goleiro
local VALID_KEEPER_HITBOX = Vector3.new(8, 8, 5)

-- Altura máxima permitida para jogador (anti-fly)
local MAX_PLAYER_HEIGHT = 50

--// ============================================================================
--// SETOR: Estado Global
--// ============================================================================

-- Rate limiting por jogador
local playerRateLimits = {} :: {[number]: {[string]: {count: number, lastReset: number, lastAction: number}}}

-- Violações por jogador
local playerViolations = {} :: {[number]: {count: number, history: {{type: string, time: number, details: string}}}}

-- Última posição conhecida por jogador (anti-teleport)
local playerLastPositions = {} :: {[number]: Vector3}

-- Último timestamp por jogador (anti-teleport)
local playerLastTimes = {} :: {[number]: number}

--// ============================================================================
--// SETOR: Funções de Whitelist
--// ============================================================================

--[[
	Verifica se o jogador é um Official (árbitro/admin).
	Officials são ignorados nas verificações de hack.
	
	@param player Player - Jogador a verificar
	@return boolean - True se for Official
]]
function AntiHack:IsOfficial(player: Player): boolean
	if not player.Team then
		return false
	end
	return player.Team.Name == "Officials"
end

--[[
	Verifica se o jogador foi modificado por comando admin recentemente.
	
	@param player Player - Jogador a verificar
	@return boolean - True se foi modificado por admin
]]
function AntiHack:IsAdminModified(player: Player): boolean
	local modified = player:GetAttribute("AdminModified")
	local modTime = player:GetAttribute("AdminModifiedTime") or 0

	-- Considera válido por 10 segundos após comando admin
	if modified and (os.time() - modTime) < 10 then
		return true
	end
	return false
end

--// ============================================================================
--// SETOR: Sistema de Rate Limiting
--// ============================================================================

--[[
	Verifica se a ação do jogador está dentro do rate limit.
	
	@param player Player - Jogador que está fazendo a ação
	@param action string - Nome da ação (SpawnRequest, ThrowEvent, etc.)
	@return boolean - True se permitido, False se bloqueado
]]
function AntiHack:CheckRateLimit(player: Player, action: string): boolean
	local userId = player.UserId
	local now = tick()

	-- Inicializa estrutura se não existir
	if not playerRateLimits[userId] then
		playerRateLimits[userId] = {}
	end

	if not playerRateLimits[userId][action] then
		playerRateLimits[userId][action] = {
			count = 0,
			lastReset = now,
			lastAction = 0
		}
	end

	local limits = RATE_LIMITS[action]
	if not limits then
		return true -- Ação sem limite definido
	end

	local playerLimit = playerRateLimits[userId][action]

	-- Reset contador a cada minuto
	if (now - playerLimit.lastReset) >= 60 then
		playerLimit.count = 0
		playerLimit.lastReset = now
	end

	-- Verifica cooldown
	if (now - playerLimit.lastAction) < limits.cooldown then
		return false
	end

	-- Verifica máximo por minuto
	if playerLimit.count >= limits.maxPerMinute then
		self:LogViolation(player, "RATE_LIMIT", action .. " spam: " .. playerLimit.count .. "/min")
		return false
	end

	-- Atualiza contadores
	playerLimit.count += 1
	playerLimit.lastAction = now

	return true
end

--// ============================================================================
--// SETOR: Sistema de Violações e Alertas
--// ============================================================================

--[[
	Registra uma violação de hack e alerta os Officials.
	
	@param player Player - Jogador que violou
	@param violationType string - Tipo de violação
	@param details string - Detalhes da violação
]]
function AntiHack:LogViolation(player: Player, violationType: string, details: string?)
	if not player then return end

	local userId = player.UserId
	local detailsStr = details or "N/A"

	-- Inicializa estrutura se não existir
	if not playerViolations[userId] then
		playerViolations[userId] = {
			count = 0,
			history = {}
		}
	end

	-- Registra violação
	playerViolations[userId].count += 1
	table.insert(playerViolations[userId].history, {
		type = violationType,
		time = os.time(),
		details = detailsStr
	})

	-- Limita histórico a 50 entradas
	if #playerViolations[userId].history > 50 then
		table.remove(playerViolations[userId].history, 1)
	end

	-- Log no console do servidor
	local message = string.format("[ANTIHACK] %s (%d): %s - %s [Total: %d]", 
		player.Name, 
		userId, 
		violationType, 
		detailsStr,
		playerViolations[userId].count
	)
	warn(message)

	-- Alerta todos os Officials
	self:AlertOfficials(player, violationType, detailsStr)
end

--[[
	Envia alerta para todos os Officials sobre uma violação.
	
	@param player Player - Jogador que violou
	@param violationType string - Tipo de violação
	@param details string - Detalhes da violação
]]
function AntiHack:AlertOfficials(player: Player, violationType: string, details: string)
	local officials = Teams:FindFirstChild("Officials")
	if not officials then return end

	local violationCount = 0
	if playerViolations[player.UserId] then
		violationCount = playerViolations[player.UserId].count
	end

	-- Envia evento para cada Official
	for _, official in officials:GetPlayers() do
		LEAGUE_EVENT:FireClient(official, "HACK_ALERT", {
			playerName = player.Name,
			playerId = player.UserId,
			violationType = violationType,
			details = details,
			totalViolations = violationCount,
			time = os.time()
		})
	end
end

--[[
	Retorna o número de violações de um jogador.
	
	@param player Player - Jogador a verificar
	@return number - Número de violações
]]
function AntiHack:GetViolationCount(player: Player): number
	if playerViolations[player.UserId] then
		return playerViolations[player.UserId].count
	end
	return 0
end

--[[
	Retorna o histórico de violações de um jogador.
	
	@param player Player - Jogador a verificar
	@return table - Histórico de violações
]]
function AntiHack:GetViolationHistory(player: Player): {{type: string, time: number, details: string}}
	if playerViolations[player.UserId] then
		return playerViolations[player.UserId].history
	end
	return {}
end

--// ============================================================================
--// SETOR: Detecções de Hack
--// ============================================================================

--[[
	Verifica speed hack (WalkSpeed alterado).
	
	@param player Player - Jogador a verificar
	@return boolean - True se está hackeando
]]
function AntiHack:CheckSpeedHack(player: Player): boolean
	-- Ignora Officials e jogadores modificados por admin
	if self:IsOfficial(player) or self:IsAdminModified(player) then
		return false
	end

	local character = player.Character
	if not character then return false end

	local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
	if not humanoid then return false end

	if humanoid.WalkSpeed > MAX_WALKSPEED then
		-- Loga violação com velocidade original
		local hackedSpeed = humanoid.WalkSpeed

		-- Reseta para velocidade NORMAL do jogo
		humanoid.WalkSpeed = SharedAttributes:GetWalkSpeed()

		self:LogViolation(player, "SPEED_HACK", "WalkSpeed: " .. math.floor(hackedSpeed) .. " -> Reset: " .. SharedAttributes:GetWalkSpeed())
		return true
	end

	return false
end

--[[
	Verifica teleport hack (mudança de posição muito rápida).
	
	@param player Player - Jogador a verificar
	@return boolean - True se está hackeando
]]
function AntiHack:CheckTeleportHack(player: Player): boolean
	-- Ignora Officials e jogadores modificados por admin
	if self:IsOfficial(player) or self:IsAdminModified(player) then
		return false
	end

	local character = player.Character
	if not character then return false end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoidRootPart then return false end

	local userId = player.UserId
	local currentPos = humanoidRootPart.Position
	local now = tick()

	-- Inicializa se não existir
	if not playerLastPositions[userId] then
		playerLastPositions[userId] = currentPos
		playerLastTimes[userId] = now
		return false
	end

	local lastPos = playerLastPositions[userId]
	local lastTime = playerLastTimes[userId]
	local deltaTime = now - lastTime

	-- Só verifica se passou tempo suficiente
	if deltaTime < 0.1 then
		return false
	end

	local distance = (currentPos - lastPos).Magnitude

	-- Calcula velocidade (studs/s)
	local speed = distance / deltaTime

	-- Se moveu muito rápido, é teleport
	if distance > MAX_TELEPORT_DISTANCE then
		-- Teleporta de volta para última posição válida
		humanoidRootPart.CFrame = CFrame.new(lastPos)
		self:LogViolation(player, "TELEPORT", "Distance: " .. math.floor(distance) .. " studs")
		return true
	end

	-- Atualiza posição
	playerLastPositions[userId] = currentPos
	playerLastTimes[userId] = now

	return false
end

--[[
	Verifica fly hack (jogador muito alto sem razão).
	
	@param player Player - Jogador a verificar
	@return boolean - True se está hackeando
]]
function AntiHack:CheckFlyHack(player: Player): boolean
	-- Ignora Officials e jogadores modificados por admin
	if self:IsOfficial(player) or self:IsAdminModified(player) then
		return false
	end

	local character = player.Character
	if not character then return false end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoidRootPart then return false end

	-- Verifica se está muito alto
	if humanoidRootPart.Position.Y > MAX_PLAYER_HEIGHT then
		self:LogViolation(player, "FLY_HACK", "Height: " .. math.floor(humanoidRootPart.Position.Y))
		return true
	end

	return false
end

--[[
	Verifica hitbox do goleiro (tamanho alterado).
	
	@param hitbox Instance - Hitbox do goleiro
	@param player Player - Jogador dono da hitbox
	@return boolean - True se está hackeando
]]
function AntiHack:CheckKeeperHitbox(hitbox: BasePart, player: Player): boolean
	if not hitbox then return false end

	if hitbox.Size ~= VALID_KEEPER_HITBOX then
		-- Corrige tamanho
		hitbox.Size = VALID_KEEPER_HITBOX
		self:LogViolation(player, "KEEPER_HBE", "Size: " .. tostring(hitbox.Size))
		return true
	end

	return false
end

--// ============================================================================
--// SETOR: Validações de Dados
--// ============================================================================

--[[
	Valida dados de arremesso (power e direção).
	
	@param power number - Força do arremesso
	@param directionData table - Dados de direção
	@return boolean - True se válido
]]
function AntiHack:ValidateThrow(power: number, directionData: any): boolean
	-- Power deve estar entre 0 e 100
	if power < 0 or power > 100 then
		return false
	end

	-- Direção deve ser vetor unitário
	if directionData and directionData.Direction then
		local magnitude = directionData.Direction.Magnitude
		if magnitude < 0.5 or magnitude > 1.5 then
			return false
		end
	end

	return true
end

--[[
	Valida distância entre dois jogadores para tackle.
	
	@param attacker Player - Jogador atacante
	@param target Player - Jogador alvo
	@param maxDistance number - Distância máxima permitida
	@return boolean - True se válido
]]
function AntiHack:ValidateTackleDistance(attacker: Player, target: Player, maxDistance: number): boolean
	local attackerChar = attacker.Character
	local targetChar = target.Character

	if not attackerChar or not targetChar then
		return false
	end

	local attackerPos = attackerChar:FindFirstChild("HumanoidRootPart")
	local targetPos = targetChar:FindFirstChild("HumanoidRootPart")

	if not attackerPos or not targetPos then
		return false
	end

	local distance = (attackerPos.Position - targetPos.Position).Magnitude
	return distance <= maxDistance
end

--// ============================================================================
--// SETOR: Loop Principal de Detecção
--// ============================================================================

-- Verifica todos os jogadores a cada 0.5 segundos
local checkInterval = 0.5
local lastCheck = 0

RunService.Heartbeat:Connect(function()
	local now = tick()

	if (now - lastCheck) < checkInterval then
		return
	end
	lastCheck = now

	for _, player in Players:GetPlayers() do
		-- Verifica speed hack
		AntiHack:CheckSpeedHack(player)

		-- Verifica teleport hack
		AntiHack:CheckTeleportHack(player)

		-- Verifica fly hack
		AntiHack:CheckFlyHack(player)
	end
end)

--// ============================================================================
--// SETOR: Cleanup de Jogador
--// ============================================================================

Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	playerRateLimits[userId] = nil
	playerLastPositions[userId] = nil
	playerLastTimes[userId] = nil
	-- Mantém violações para histórico (não limpa playerViolations)
end)

--// ============================================================================
--// SETOR: Retorno do Módulo
--// ============================================================================

return AntiHack
