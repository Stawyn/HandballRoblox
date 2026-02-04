local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PingModule = {}
local PlayerPings = {} :: {[number]: {[number]: number}}

local NETWORK_FOLDER = ReplicatedStorage:WaitForChild("Network") :: Folder
local PING_FUNCTION = NETWORK_FOLDER:WaitForChild("Ping") :: RemoteFunction
local MAX_PINGS_SAVE = 6 -- Guarda os 6 pings mais recentes do jogador
local MAX_CONSIDERATION = 5

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

function PingModule:GetPlayerPingSequence(player: Player)
	return PlayerPings[player.UserId]
end

function PingModule:Initialize(player: Player, pingInstance: NumberValue)
	local i = 0
	PlayerPings[player.UserId] = table.create(MAX_PINGS_SAVE, -1)
	
	while (player:IsDescendantOf(Players)) do
		local elapsingTime = os.clock()
		local receivedFeedback = false

		task.delay(1, function()
			if not receivedFeedback then
				pingInstance.Value = 1000
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