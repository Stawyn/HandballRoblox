--[[
    ================================================================================
    MÓDULO: StaminaServer
    ================================================================================
    Descrição: Sistema autoritativo de stamina no servidor. Controla sprint, walkspeed
               e validações anti-cheat para prevenir speed hacks e stamina infinita.
    
    Funcionalidades:
        - Gerenciamento de estado de stamina por jogador
        - Validação e aplicação segura de WalkSpeed
        - APIs para outros módulos (Jump, redução de stamina)
        - Prevenção de regeneração excessiva
    
    Autor: Sistema ABH
    ================================================================================
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedAttributes = require(ReplicatedStorage.Modules.Implementation.SharedAttributes)

local StaminaServer = {}

-- Configurações (Sincronizadas com Cliente)
local STAMINA_DURATION = 7
local DRAIN_RATE = 100 / STAMINA_DURATION
local INCREASE_RATE = 20
local JUMP_DECREASE_RATE = 24
local RUN_REFRESH = 15
local REGEN_DELAY = 0.5 -- 0.25 (cliente) + margem

-- Estado dos jogadores
local playerStates = {}

-- Eventos (serão criados pelo Loader se não existirem, mas referenciamos aqui)
local NETWORK_FOLDER = ReplicatedStorage:WaitForChild("Network")
local STAMINA_EVENT = NETWORK_FOLDER:FindFirstChild("StaminaEvent") 
if not STAMINA_EVENT then
	STAMINA_EVENT = Instance.new("RemoteEvent")
	STAMINA_EVENT.Name = "StaminaEvent"
	STAMINA_EVENT.Parent = NETWORK_FOLDER
end

local function initPlayer(player)
	playerStates[player] = {
		stamina = 100,
		sprinting = false,
		exhausted = false,
		lastSprintTime = 0,
		lastUpdate = os.clock()
	}
	
	-- Reset WalkSpeed inicial
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.WalkSpeed = SharedAttributes:GetWalkSpeed()
	end
end

-- Loop principal de processamento (Heartbeat)
RunService.Heartbeat:Connect(function(deltaTime)
	for player, state in pairs(playerStates) do
		if not player.Parent then 
			playerStates[player] = nil
			continue 
		end
		
		local character = player.Character
		if not character then continue end
		
		local humanoid = character:FindFirstChild("Humanoid")
		if not humanoid or humanoid.Health <= 0 then continue end
		
		local isMoving = humanoid.MoveDirection.Magnitude > 0
		
		-- Lógica de Drenagem / Regeneração
		if state.sprinting and isMoving then
			state.lastSprintTime = os.clock()
			state.stamina = math.max(0, state.stamina - (DRAIN_RATE * deltaTime))
			
			if state.stamina <= 0 then
				state.sprinting = false
				state.exhausted = true
				humanoid.WalkSpeed = SharedAttributes:GetWalkSpeed()
				STAMINA_EVENT:FireClient(player, "ForceStopSprint")
			end
		else
			if (os.clock() - state.lastSprintTime) > REGEN_DELAY then
				state.stamina = math.min(100, state.stamina + (INCREASE_RATE * deltaTime))
				
				if state.exhausted and state.stamina > RUN_REFRESH then
					state.exhausted = false
				end
			end
		end
		
		-- Sincronização periódica ou crítica (apenas se mudar significativamente para economizar banda)
		-- Aqui faremos sincronização apenas crítica (exhausted ou full) ou podemos confiar na simulação do cliente
		-- Para anti-cheat, o importante é o servidor ter a autoridade final.
	end
end)

-- Handlers de Evento
STAMINA_EVENT.OnServerEvent:Connect(function(player, action, value)
	local state = playerStates[player]
	if not state then initPlayer(player); state = playerStates[player] end
	
	local character = player.Character
	local humanoid = character and character:FindFirstChild("Humanoid")
	
	if action == "Sprint" then
		local wantSprint = value == true
		
		if wantSprint then
			if state.exhausted or state.stamina <= 0 then return end
			-- Verificar se pode sprintar (não está segurando KeeperTool, etc)
			if character:FindFirstChild("KeeperTool") then return end
			
			state.sprinting = true
			if humanoid then
				humanoid.WalkSpeed = SharedAttributes:GetSprintSpeed()
			end
		else
			state.sprinting = false
			if humanoid then
				humanoid.WalkSpeed = SharedAttributes:GetWalkSpeed()
			end
		end
		
	elseif action == "Jump" then
		-- Validar se pode pular
		if state.stamina < JUMP_DECREASE_RATE then
			return -- Rejeita pulo (cliente deve impedir, mas servidor garante)
		end
		
		-- Consumir stamina
		state.stamina = math.max(0, state.stamina - JUMP_DECREASE_RATE)
		
		-- O pulo físico acontece no cliente, mas se detectarmos pulo sem stamina, podemos punir/rollback
		-- Como Humanoid.Jump é replicado, podemos forçar Jump = false se quisermos ser muito rigorosos
		-- Mas o consumo de stamina é o mais importante aqui.
	end
end)

Players.PlayerAdded:Connect(initPlayer)
Players.PlayerRemoving:Connect(function(player)
	playerStates[player] = nil
end)

-- API Pública
function StaminaServer:ConsumeStamina(player, amount)
	local state = playerStates[player]
	if state then
		state.stamina = math.max(0, state.stamina - amount)
	end
end

function StaminaServer:ResetStamina(player)
	local state = playerStates[player]
	if state then
		state.stamina = 100
		state.exhausted = false
	end
end

return StaminaServer
