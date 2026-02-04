--[[
    ================================================================================
    MÓDULO: Player
    ================================================================================
    Descrição: Gerenciamento de jogadores no servidor - inicialização, perfis,
               ferramentas por time e persistência de dados.
    
    Funcionalidades:
        - Inicialização de jogador (atributos, leaderstats)
        - Carregamento de perfil (ProfileStore)
        - Distribuição de ferramentas por time
        - Teletransporte ao mudar de time
        - Gerenciamento de keybinds persistentes
    
    Ferramentas por Time:
        - Officials: SpawnTool, RefSpawnTool, PenaltySpawnTool, RC, YC
        - Goalkeeper: KeeperTool
        - Lobby (sem partida): SpawnTool, KeeperTool
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: SERVIÇOS E DEPENDÊNCIAS
--// ============================================================================

local PlayerModule = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local KeybindsInit = require("./KeybindInit")
local CharacterModule = require("../Implementation/PlayerCharacter")
local PingModule = require("../Implementation/PingModule")
local ProfileStore = require("../Implementation/ProfileStore")

--// ============================================================================
--// SETOR: REFERÊNCIAS E CONSTANTES
--// ============================================================================

-- Rede
local PLAYER_DATA = ReplicatedStorage:WaitForChild("Network"):WaitForChild("PlayerData") :: RemoteFunction
local DATA_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Data")

-- Ferramentas
local PENALTY_SPAWN_TOOL = ServerStorage:WaitForChild("PenaltySpawnTool") :: Tool
local REF_SPAWN_TOOL = ServerStorage:WaitForChild("RefSpawnTool") :: Tool
local SPAWN_TOOL = ServerStorage:WaitForChild("SpawnTool") :: Tool
local KEEPER_TOOL = ServerStorage:WaitForChild("KeeperTool") :: Tool
local RC_TOOL = ServerStorage:WaitForChild("RC") :: Tool
local YC_TOOL = ServerStorage:WaitForChild("YC") :: Tool

-- DataStore Key (diferente para Studio vs Produção)
local DS_KEY = if RunService:IsStudio() then "DEV_DATA" else "PROD_DATA"

-- Template de perfil padrão
local PROFILE_TEMPLATE = {
	Inputs = KeybindsInit.DefaultActions,
	Coins = 0,
	Emotes = {}
}

-- Atributos padrão do jogador
local ATTRIBUTES = {
	{"CurrentHand", "R"},
	{"GoalkeeperCooldown", 0}
}

--// ============================================================================
--// SETOR: ESTADO
--// ============================================================================

local playerStore = ProfileStore.New(DS_KEY, PROFILE_TEMPLATE)
local profiles: {[Player]: typeof(playerStore:StartSessionAsync())} = {}

--// ============================================================================
--// SETOR: POSIÇÕES DE SPAWN POR TIME
--// ============================================================================

local SPAWN_POSITIONS = {
	["-Home Goalkeeper"] = CFrame.new(Vector3.new(-126, 15, 0), Vector3.new(0, 15, 0)),
	["-Away Goalkeeper"] = CFrame.new(Vector3.new(126, 15, 0), Vector3.new(0, 15, 0)),
	["Home Team"] = CFrame.new(Vector3.new(-82, 10, 0), Vector3.new(0, 10, 0)),
	["Away Team"] = CFrame.new(Vector3.new(82, 10, 0), Vector3.new(0, 10, 0)),
}

--// ============================================================================
--// SETOR: FUNÇÕES DE FERRAMENTAS
--// ============================================================================

--- Lista de nomes de ferramentas para limpeza
local TOOL_NAMES = {"SpawnTool", "RefSpawnTool", "PenaltySpawnTool", "RC", "YC", "KeeperTool"}

--- Limpa ferramentas do jogador
local function clearPlayerTools(player: Player)
	for _, toolName in TOOL_NAMES do
		local t = player.Backpack:FindFirstChild(toolName)
		if t then t:Destroy() end
		if player.Character then
			local tc = player.Character:FindFirstChild(toolName)
			if tc then tc:Destroy() end
		end
	end
end

--- Dá ferramentas baseado no time
local function giveTeamTools(player: Player)
	if not player.Team then return end
	local teamName = player.Team.Name

	if teamName == "Officials" then
		SPAWN_TOOL:Clone().Parent = player.Backpack
		REF_SPAWN_TOOL:Clone().Parent = player.Backpack
		PENALTY_SPAWN_TOOL:Clone().Parent = player.Backpack
		RC_TOOL:Clone().Parent = player.Backpack
		YC_TOOL:Clone().Parent = player.Backpack
	elseif teamName:find("Goalkeeper") then
		KEEPER_TOOL:Clone().Parent = player.Backpack
	elseif teamName == "Lobby" and DATA_FOLDER.Match.Value == false then
		SPAWN_TOOL:Clone().Parent = player.Backpack
		KEEPER_TOOL:Clone().Parent = player.Backpack
	end
end

--// ============================================================================
--// SETOR: HANDLERS DE EVENTOS
--// ============================================================================

--- Callback quando jogador muda de time
function onTeamChanged(player: Player)
	clearPlayerTools(player)

	-- Teletransporte ao mudar de time
	task.defer(function()
		if player:GetAttribute("IsRejoining") == true then return end

		local character = player.Character
		if character and character:FindFirstChild("HumanoidRootPart") and player.Team then
			local spawnCFrame = SPAWN_POSITIONS[player.Team.Name]
			if spawnCFrame then
				character:PivotTo(spawnCFrame)
			end
		end
	end)

	giveTeamTools(player)
end

--// ============================================================================
--// SETOR: CURRENCY & EMOTES
--// ============================================================================

function PlayerModule:AddCoins(player: Player, amount: number)
	local profile = profiles[player]
	if profile then
		profile.Data.Coins = (profile.Data.Coins or 0) + amount
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats and leaderstats:FindFirstChild("Coins") then
			leaderstats.Coins.Value = profile.Data.Coins
		end
	end
end

function PlayerModule:AddEmote(player: Player, emoteName: string)
	local profile = profiles[player]
	if profile then
		if not profile.Data.Emotes then profile.Data.Emotes = {} end
		if not table.find(profile.Data.Emotes, emoteName) then
			table.insert(profile.Data.Emotes, emoteName)
			
			local emotesFolder = player:FindFirstChild("Emotes")
			if emotesFolder and not emotesFolder:FindFirstChild(emoteName) then
				local val = Instance.new("StringValue")
				val.Name = emoteName
				val.Parent = emotesFolder
			end
		end
	end
end

--// ============================================================================
--// SETOR: INICIALIZAÇÃO DE JOGADOR
--// ============================================================================

--- Inicializa jogador quando entra no jogo
function PlayerModule:OnPlayerAdded(player: Player)
	-- Leaderstats
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local ping = Instance.new("NumberValue")
	ping.Name = "Ping"
	ping.Value = 500
	ping.Parent = leaderstats

	local coins = Instance.new("NumberValue")
	coins.Name = "Coins"
	coins.Value = 0
	coins.Parent = leaderstats

	local device = Instance.new("StringValue")
	device.Name = "Device"
	device.Value = "🖥️"
	device.Parent = leaderstats

	-- Inicializa character module
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
			player:Kick("Profile season end - Please rejoin")
		end)

		if player.Parent == Players then
			profiles[player] = profile
		else
			profile:EndSession()
		end

		KeybindsInit:Start(player, profile.Data.Inputs)

		-- Carregar Coins
		if leaderstats:FindFirstChild("Coins") then
			leaderstats.Coins.Value = profile.Data.Coins or 0
		end

		-- Carregar Emotes
		local emotesFolder = Instance.new("Folder")
		emotesFolder.Name = "Emotes"
		emotesFolder.Parent = player
		if profile.Data.Emotes then
			for _, emoteName in ipairs(profile.Data.Emotes) do
				local val = Instance.new("StringValue")
				val.Name = emoteName
				val.Parent = emotesFolder
			end
		end
	else
		player:Kick("Profile load fail - Please rejoin")
	end

	-- Configura atributos
	for _, attributeVector in ATTRIBUTES do
		player:SetAttribute(attributeVector[1] :: string, attributeVector[2])
	end

	leaderstats.Parent = player

	-- Conecta eventos
	coroutine.wrap(onTeamChanged)(player)
	player:GetPropertyChangedSignal("Team"):Connect(function()
		coroutine.wrap(onTeamChanged)(player)
	end)
	player.CharacterAdded:Connect(function()
		coroutine.wrap(onTeamChanged)(player)
	end)

	-- Inicializa ping
	PingModule:Initialize(player, ping)
end

--// ============================================================================
--// SETOR: CONEXÕES DE EVENTOS
--// ============================================================================

Players.PlayerAdded:Connect(function(player)
	PlayerModule:OnPlayerAdded(player)
end)

-- Inicializa jogadores que já estão no jogo (Studio)
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
--// SETOR: REMOTE FUNCTION - PLAYER DATA
--// ============================================================================

--- Handler para mudanças de keybinds
-- TODO: Refatorar para sistema mais limpo
PLAYER_DATA.OnServerInvoke = function(player: Player, action, data)
	local profile = profiles[player]
	if not profile then
		player:Kick("Profile load fail - Please rejoin")
		return false, "No profile"
	end

	if action == "CHANGE_KEYBOARD_KEYBIND" then
		local context = data[1] :: string
		local actionName = data[2] :: string
		local keybind = data[3] :: string

		if not context or not actionName or not keybind then
			return false, "Insufficient arguments. Please try again"
		end

		if not Enum.KeyCode[keybind] then
			return false, "Invalid keybind or it's not supported. Please try again with other one"
		end

		profile.Data.Inputs[context][actionName]["Keyboard"] = keybind
		return true

	elseif action == "CHANGE_GAMEPAD_CONTROLS" then
		local context = data[1] :: string
		local actionName = data[2] :: string
		local keybind = data[3] :: string

		if not context or not actionName or not keybind then
			return false, "Insufficient arguments. Please try again"
		end

		if not Enum.KeyCode[keybind] then
			return false, "Invalid keybind or it's not supported. Please try again with other one"
		end

		profile.Data.Inputs[context][actionName]["Controller"] = keybind
		return true

	elseif action == "CHANGE_MOBILE_CONTROLS" then
		local context = data[1] :: string
		local actionName = data[2] :: string
		local offset = data[3] :: {number}
		local scale = math.clamp(data[4], 0.5, 2) :: number 

		if not context or not actionName or not offset or not scale then
			return false, "Insufficient arguments. Please try again"
		end

		profile.Data.Inputs[context][actionName]["Scalar"] = scale 
		profile.Data.Inputs[context][actionName]["MobOffset"] = {offset[1], offset[2]}
		return true

	elseif action == "RESET_KEYBINDS" then
		profile.Data.Inputs = table.clone(PROFILE_TEMPLATE.Inputs)
		return true, PROFILE_TEMPLATE.Inputs
	end

	return false, "Unknown action"
end

return PlayerModule
