--[[
    ================================================================================
    MODULO: PingModule
    ================================================================================
    Descricao: Sistema de monitoramento de latencia (ping) do servidor.
               Rastreia o RTT de cada jogador para compensacao de lag.
    
    Funcionalidades:
        - Medicao de ping via RemoteFunction
        - Historico dos ultimos 6 pings por jogador
        - Calculo de valor esperado baseado nos 5 mais recentes
        - Timeout automatico de 1000ms para clientes nao responsivos
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: SERVICOS
--// ============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// ============================================================================
--// SETOR: MODULO E ESTADO
--// ============================================================================

local PingModule = {}
local PlayerPings = {} :: {[number]: {[number]: number}}

--// ============================================================================
--// SETOR: CONSTANTES
--// ============================================================================

local NETWORK_FOLDER = ReplicatedStorage:WaitForChild("Network") :: Folder
local PING_FUNCTION = NETWORK_FOLDER:WaitForChild("Ping") :: RemoteFunction
local MAX_PINGS_SAVE = 6 -- Guarda os 6 pings mais recentes do jogador
local MAX_CONSIDERATION = 5 -- Usa os 5 mais recentes para calculo
local TIMEOUT_MS = 1000 -- Timeout em ms

--// ============================================================================
--// SETOR: FUNCOES PUBLICAS
--// ============================================================================

--- Calcula o valor esperado de ping baseado nos ultimos pings
-- @param player Player - O jogador
-- @return number - Ping medio em ms, ou -1 se dados insuficientes
function PingModule:GetExpectedValueFromPlayer(player: Player)
	if not PlayerPings[player.UserId] then
		return -1
	end
	
	local sum = 0
	local count = 0
	for i = 1, MAX_CONSIDERATION do
		local value = PlayerPings[player.UserId][i]
		if value == -1 then
			return -1 -- Sem dados o suficiente
		end
		
		sum += value
		count += 1
	end
	
	local expectedValue = sum / count
	return expectedValue
end

--- Obtem a sequencia completa de pings do jogador
-- @param player Player - O jogador
-- @return table? - Array com historico de pings
function PingModule:GetPlayerPingSequence(player: Player)
	return PlayerPings[player.UserId]
end

--- Inicializa o monitoramento de ping para um jogador
-- @param player Player - O jogador a monitorar
-- @param pingInstance NumberValue - Value para armazenar o ping atual
function PingModule:Initialize(player: Player, pingInstance: NumberValue)
	local i = 0
	PlayerPings[player.UserId] = table.create(MAX_PINGS_SAVE, -1)
	
	while (player:IsDescendantOf(Players)) do
		local elapsingTime = os.clock()
		local receivedFeedback = false

		-- Timeout handler
		task.delay(1, function()
			if not receivedFeedback then
				pingInstance.Value = TIMEOUT_MS
				local currentIndex = ((MAX_PINGS_SAVE - i - 1) % MAX_PINGS_SAVE) + 1
				PlayerPings[player.UserId][currentIndex] = pingInstance.Value
				i += 1
			end
		end)

		local success, returned = pcall(function()
			return PING_FUNCTION:InvokeClient(player)
		end)

		if success then
			local responseTime = os.clock() - elapsingTime
			pingInstance.Value = math.floor(responseTime * 1000)
			local currentIndex = ((MAX_PINGS_SAVE - i - 1) % MAX_PINGS_SAVE) + 1
			PlayerPings[player.UserId][currentIndex] = pingInstance.Value
			i += 1
			receivedFeedback = true
		end

		task.wait(1)
	end
	
	-- O jogador saiu do jogo
	table.clear(PlayerPings[player.UserId])
end

return PingModule