--[[
	================================================================================
	MÓDULO: Player (Gerenciamento de Jogadores)
	================================================================================
	
	Descrição:
		Módulo responsável por gerenciar jogadores no servidor:
		- Inicialização de jogadores ao entrar
		- Gerenciamento de times e ferramentas
		- Sistema de keybinds persistentes (ProfileStore)
		- Leaderstats (Ping, Device)
	
	Autor: Sistema ABH
	Refatorado: Documentação, remoção de duplicação em handlers de keybind
	================================================================================
]]

--// ============================================================================
--// SETOR: Definição do Módulo
--// ============================================================================

local PlayerModule = {}

--// ============================================================================
--// SETOR: Serviços do Roblox
--// ============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

--// ============================================================================
--// SETOR: Dependências
--// ============================================================================

local KeybindsInit = require("./KeybindInit")
local CharacterModule = require("../Implementation/PlayerCharacter")
local PingModule = require("../Implementation/PingModule")
local ProfileStore = require("../Implementation/ProfileStore")

--// ============================================================================
--// SETOR: Referências
--// ============================================================================

local PLAYER_DATA = ReplicatedStorage:WaitForChild("Network"):WaitForChild("PlayerData") :: RemoteFunction
local DATA_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Data")

--// ============================================================================
--// SETOR: Ferramentas Disponíveis
--// ============================================================================

local PENALTY_SPAWN_TOOL = ServerStorage:WaitForChild("PenaltySpawnTool") :: Tool
local REF_SPAWN_TOOL = ServerStorage:WaitForChild("RefSpawnTool") :: Tool
local SPAWN_TOOL = ServerStorage:WaitForChild("SpawnTool") :: Tool
local KEEPER_TOOL = ServerStorage:WaitForChild("KeeperTool") :: Tool
local RC_TOOL = ServerStorage:WaitForChild("RC") :: Tool
local YC_TOOL = ServerStorage:WaitForChild("YC") :: Tool

--// ============================================================================
--// SETOR: Constantes de DataStore
--// ============================================================================

local DS_KEY
if RunService:IsStudio() then
	DS_KEY = "DEV_DATA"
else
	DS_KEY = "PROD_DATA"
end

local PROFILE_TEMPLATE = {
	Inputs = KeybindsInit.DefaultActions
}

--// ============================================================================
--// SETOR: Estado Global
--// ============================================================================

local playerStore = ProfileStore.New(DS_KEY, PROFILE_TEMPLATE)
local profiles: {[Player]: typeof(playerStore:StartSessionAsync())} = {}

--// ============================================================================
--// SETOR: Constantes de Atributos Padrào
--// ============================================================================

local DEFAULT_ATTRIBUTES = {
	{"CurrentHand", "R"},      -- mão padrào (R = direita)
	{"GoalkeeperCooldown", 0}  -- Cooldown do goleiro
}

--// ============================================================================
--// SETOR: Constantes de Spawn por Time
--// ============================================================================

local TEAM_SPAWN_POSITIONS = {
	["-Home Goalkeeper"] = {position = Vector3.new(-126, 15, 0), lookAt = Vector3.new(0, 15, 0)},
	["-Away Goalkeeper"] = {position = Vector3.new(126, 15, 0), lookAt = Vector3.new(0, 15, 0)},
	["Home Team"] = {position = Vector3.new(-82, 10, 0), lookAt = Vector3.new(0, 10, 0)},
	["Away Team"] = {position = Vector3.new(82, 10, 0), lookAt = Vector3.new(0, 10, 0)},
}

--// ============================================================================
--// SETOR: Lista de Ferramentas por Time
--// ============================================================================

local TOOLS_TO_CLEAR = {"SpawnTool", "RefSpawnTool", "PenaltySpawnTool", "RC", "YC", "KeeperTool"}

--// ============================================================================
--// SETOR: Funções Auxiliares
--// ============================================================================

--- Remove ferramentas antigas do jogador (Backpack e Character)
local function clearPlayerTools(player: Player)
	for _, toolName in TOOLS_TO_CLEAR do
		local t = player.Backpack:FindFirstChild(toolName)
		if t then t:Destroy() end
		if player.Character then
			local tc = player.Character:FindFirstChild(toolName)
			if tc then tc:Destroy() end
		end
	end
end

--- Teletransporta jogador para posição do time
local function teleportToTeamSpawn(player: Player)
	if player:GetAttribute("IsRejoining") == true then
		return
	end

	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") or not player.Team then
		return
	end

	local teamName = player.Team.Name
	local spawnData = TEAM_SPAWN_POSITIONS[teamName]

	if spawnData then
		character:PivotTo(CFrame.new(spawnData.position, spawnData.lookAt))
	end
end

--- Dá ferramentas baseado no time do jogador
local function giveTeamTools(player: Player)
	if not player.Team then return end

	local teamName = player.Team.Name

	if teamName == "Officials" then
		-- Árbitros recebem todas as ferramentas de controle
		SPAWN_TOOL:Clone().Parent = player.Backpack
		REF_SPAWN_TOOL:Clone().Parent = player.Backpack
		PENALTY_SPAWN_TOOL:Clone().Parent = player.Backpack
		RC_TOOL:Clone().Parent = player.Backpack
		YC_TOOL:Clone().Parent = player.Backpack

	elseif teamName:find("Goalkeeper") then
		-- Goleiros recebem ferramenta de keeper
		KEEPER_TOOL:Clone().Parent = player.Backpack

	elseif teamName == "Lobby" then
		-- Lobby só recebe ferramentas se não houver partida
		if DATA_FOLDER.Match.Value == false then
			SPAWN_TOOL:Clone().Parent = player.Backpack
			KEEPER_TOOL:Clone().Parent = player.Backpack
		end
	end
end

--// ============================================================================
--// SETOR: Handler de Mudança de Time
--// ============================================================================

--- Processa mudança de time do jogador
function onTeamChanged(player: Player)
	-- Limpa ferramentas antigas
	clearPlayerTools(player)

	-- Teletransporta para spawn do time
	task.defer(function()
		teleportToTeamSpawn(player)
	end)

	-- Dá ferramentas do novo time
	giveTeamTools(player)
end

--// ============================================================================
--// SETOR: Handler de Keybinds (Refatorado - Sem Duplicação)
--// ============================================================================

--- Valida e aplica mudança de keybind
-- @param profile - Perfil do jogador
-- @param context - Contexto do input (ex: "Throw Tool")
-- @param action - Ação específica (ex: "Throw")
-- @param keybind - Novo keybind (string do Enum.KeyCode)
-- @param inputType - Tipo de input ("Keyboard", "Controller", ou nil para mobile offset)
-- @return success, errorMessage
local function handleKeybindChange(profile, context: string, action: string, keybind: string, inputType: string): (boolean, string?)
	-- Validação de argumentos
	if not context or not action or not keybind then
		return false, "Insufficient arguments. Please try again"
	end

	-- Validação do keybind (deve ser um KeyCode válido)
	if not Enum.KeyCode[keybind] then
		return false, "Invalid keybind or it's not supported. Please try again with other one"
	end

	-- Aplica a mudança
	profile.Data.Inputs[context][action][inputType] = keybind
	return true, nil
end

--- Handler de mudança de controles mobile (offset e escala)
local function handleMobileControlsChange(profile, context: string, action: string, offset: {number}, scale: number): (boolean, string?)
	-- Validação de argumentos
	if not context or not action or not offset or not scale then
		return false, "Insufficient arguments. Please try again"
	end

	-- Clamp da escala entre 0.5 e 2
	scale = math.clamp(scale, 0.5, 2)

	-- Aplica as mudanças
	profile.Data.Inputs[context][action]["Scalar"] = scale 
	profile.Data.Inputs[context][action]["MobOffset"] = {offset[1], offset[2]}
	return true, nil
end

--// ============================================================================
--// SETOR: Inicialização de Jogador
--// ============================================================================

function PlayerModule:OnPlayerAdded(player: Player)
	-- Cria leaderstats
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local ping = Instance.new("NumberValue")
	ping.Name = "Ping"
	ping.Value = 500
	ping.Parent = leaderstats

	local device = Instance.new("StringValue")
	device.Name = "Device"
	device.Value = "🖥️"
	device.Parent = leaderstats

	-- Inicializa módulo de personagem
	CharacterModule:Init(player)

	-- Carrega perfil do ProfileStore
	local profile = playerStore:StartSessionAsync(`{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile ~= nil then
		profile:AddUserId(player.UserId)
		profile:Reconcile()

		profile.OnSessionEnd:Connect(function()
			profiles[player] = nil
			player:Kick("Profile session end - Please rejoin")
		end)

		if player.Parent == Players then
			profiles[player] = profile
		else
			profile:EndSession()
		end

		KeybindsInit:Start(player, profile.Data.Inputs)
	else
		player:Kick("Profile load fail - Please rejoin")
	end

	-- Aplica atributos padrào
	for _, attributeVector in DEFAULT_ATTRIBUTES do
		player:SetAttribute(attributeVector[1] :: string, attributeVector[2])
	end

	leaderstats.Parent = player

	-- Conecta handlers de time
	coroutine.wrap(onTeamChanged)(player)
	player:GetPropertyChangedSignal("Team"):Connect(function()
		coroutine.wrap(onTeamChanged)(player)
	end)
	player.CharacterAdded:Connect(function()
		coroutine.wrap(onTeamChanged)(player)
	end)

	-- Inicializa módulo de ping
	PingModule:Initialize(player, ping)
end

--// ============================================================================
--// SETOR: Conexões de Jogadores
--// ============================================================================

Players.PlayerAdded:Connect(function(player)
	PlayerModule:OnPlayerAdded(player)
end)

-- Processa jogadores que já estavam no servidor
for _, player in Players:GetPlayers() do
	task.spawn(function()
		PlayerModule:OnPlayerAdded(player)
	end)
end

Players.PlayerRemoving:Connect(function(player)
	local profile = profiles[player]
	if profile ~= nil then
		profile:EndSession()
	end
end)

--// ============================================================================
--// SETOR: Handler de RemoteFunction (PlayerData)
--// ============================================================================

PLAYER_DATA.OnServerInvoke = function(player: Player, action, data)
	local profile = profiles[player]

	-- Valida que o perfil existe
	if not profile then
		player:Kick("Profile load fail - Please rejoin")
		return false, "Profile not loaded"
	end

	-- Handler de mudança de keybind do teclado
	if action == "CHANGE_KEYBOARD_KEYBIND" then
		local context = data[1] :: string
		local actionName = data[2] :: string
		local keybind = data[3] :: string
		return handleKeybindChange(profile, context, actionName, keybind, "Keyboard")

		-- Handler de mudança de keybind do controle
	elseif action == "CHANGE_GAMEPAD_CONTROLS" then
		local context = data[1] :: string
		local actionName = data[2] :: string
		local keybind = data[3] :: string
		return handleKeybindChange(profile, context, actionName, keybind, "Controller")

		-- Handler de mudança de controles mobile
	elseif action == "CHANGE_MOBILE_CONTROLS" then
		local context = data[1] :: string
		local actionName = data[2] :: string
		local offset = data[3] :: {number}
		local scale = data[4] :: number
		return handleMobileControlsChange(profile, context, actionName, offset, scale)

		-- Handler de reset de keybinds
	elseif action == "RESET_KEYBINDS" then
		profile.Data.Inputs = table.clone(PROFILE_TEMPLATE.Inputs)
		return true, PROFILE_TEMPLATE.Inputs
	end

	return false, "Unknown action"
end

--// ============================================================================
--// SETOR: Retorno do Módulo
--// ============================================================================

return PlayerModule
