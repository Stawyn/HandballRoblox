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

local PLAYER_DATA = ReplicatedStorage:WaitForChild("Network"):WaitForChild("PlayerData") :: RemoteFunction
local DATA_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Data")
local PENALTY_SPAWN_TOOL = ServerStorage:WaitForChild("PenaltySpawnTool") :: Tool
local REF_SPAWN_TOOL = ServerStorage:WaitForChild("RefSpawnTool") :: Tool
local SPAWN_TOOL = ServerStorage:WaitForChild("SpawnTool") :: Tool
local KEEPER_TOOL = ServerStorage:WaitForChild("KeeperTool") :: Tool
local RC_TOOL = ServerStorage:WaitForChild("RC") :: Tool
local YC_TOOL = ServerStorage:WaitForChild("YC") :: Tool

local DS_KEY
if RunService:IsStudio() then
	DS_KEY = "DEV_DATA"
else
	DS_KEY = "PROD_DATA"
end

local PROFILE_TEMPLATE = {
	Inputs = KeybindsInit.DefaultActions
}

local playerStore = ProfileStore.New(DS_KEY, PROFILE_TEMPLATE)
local profiles: {[Player]: typeof(playerStore:StartSessionAsync())} = {}

local ATTRIBUTES = {
	{"CurrentHand", "R"},
	{"GoalkeeperCooldown", 0}
}

function onTeamChanged(player: Player)
	-- Raposa: Limpar ferramentas antigas ao mudar de time
	for _, toolName in {"SpawnTool", "RefSpawnTool", "PenaltySpawnTool", "RC", "YC", "KeeperTool"} do
		local t = player.Backpack:FindFirstChild(toolName)
		if t then t:Destroy() end
		if player.Character then
			local tc = player.Character:FindFirstChild(toolName)
			if tc then tc:Destroy() end
		end
	end

	-- Raposa: Teletransporte ao mudar de time
	task.defer(function()
		if player:GetAttribute("IsRejoining") == true then
			return
		end

		local character = player.Character
		if character and character:FindFirstChild("HumanoidRootPart") and player.Team then
			local teamName = player.Team.Name
			if teamName == "-Home Goalkeeper" then
				character:PivotTo(CFrame.new(Vector3.new(-126, 15, 0), Vector3.new(0, 15, 0)))
			elseif teamName == "-Away Goalkeeper" then
				character:PivotTo(CFrame.new(Vector3.new(126, 15, 0), Vector3.new(0, 15, 0)))
			elseif teamName == "Home Team" then
				character:PivotTo(CFrame.new(Vector3.new(-82, 10, 0), Vector3.new(0, 10, 0)))
			elseif teamName == "Away Team" then
				character:PivotTo(CFrame.new(Vector3.new(82, 10, 0), Vector3.new(0, 10, 0)))
			end
		end
	end)

	if player.Team and player.Team.Name == "Officials" then
		local spawnTool = SPAWN_TOOL:Clone()
		spawnTool.Parent = player.Backpack

		local refSpawnTool = REF_SPAWN_TOOL:Clone()
		refSpawnTool.Parent = player.Backpack

		local penaltySpawnTool = PENALTY_SPAWN_TOOL:Clone()
		penaltySpawnTool.Parent = player.Backpack

		local redCardTool = RC_TOOL:Clone()
		redCardTool.Parent = player.Backpack

		local yellowCardTool = YC_TOOL:Clone()
		yellowCardTool.Parent = player.Backpack

	elseif player.Team and player.Team.Name:find("Goalkeeper") then
		local keeperTool = KEEPER_TOOL:Clone()
		keeperTool.Parent = player.Backpack
	elseif player.Team and player.Team.Name == "Lobby" then
		if DATA_FOLDER.Match.Value == false then
			local spawnTool = SPAWN_TOOL:Clone()
			spawnTool.Parent = player.Backpack

			local keeperTool = KEEPER_TOOL:Clone()
			keeperTool.Parent = player.Backpack
		end
	end
end

function PlayerModule:OnPlayerAdded(player: Player)
	local currentIndex = 0

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

	task.spawn(function()
		local GuiService = game:GetService("GuiService")
		local UserInputService = game:GetService("UserInputService")

		-- Simple server-side check for TouchEnabled usually works or via attribute/client signal
		-- Since this is server side, we rely on a remote or assume PC then update
	end)

	CharacterModule:Init(player)

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
	else
		player:Kick("Profile load fail - Please rejoin")
	end

	for _, attributeVector in ATTRIBUTES do
		player:SetAttribute(attributeVector[1] :: string, attributeVector[2])
	end

	leaderstats.Parent = player

	coroutine.wrap(onTeamChanged)(player)
	player:GetPropertyChangedSignal("Team"):Connect(function()
		coroutine.wrap(onTeamChanged)(player)
	end)
	player.CharacterAdded:Connect(function()
		coroutine.wrap(onTeamChanged)(player)
	end)

	PingModule:Initialize(player, ping)
end

Players.PlayerAdded:Connect(function(player)
	PlayerModule:OnPlayerAdded(player)
end)
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

-- TODO: REWRITE THIS PIECE OF GARBAGE
PLAYER_DATA.OnServerInvoke = function(player: Player, action, data)
	if action == "CHANGE_KEYBOARD_KEYBIND" then
		local profile = profiles[player]
		if profile then
			local context = data[1] :: string
			local action = data[2] :: string
			local keybind = data[3] :: string

			if not context or not action or not keybind then
				return false, "Insufficient arguments. Please try again"
			end

			if not Enum.KeyCode[keybind] then
				return false, "Invalid keybind or it's not suported. Please try again with other one"
			end

			profile.Data.Inputs[context][action]["Keyboard"] = keybind
			return true
		else
			player:Kick("Profile load fail - Please rejoin")
		end
	elseif action == "CHANGE_GAMEPAD_CONTROLS" then
		local profile = profiles[player]
		if profile then
			local context = data[1] :: string
			local action = data[2] :: string
			local keybind = data[3] :: string

			if not context or not action or not keybind then
				return false, "Insufficient arguments. Please try again"
			end

			if not Enum.KeyCode[keybind] then
				return false, "Invalid keybind or it's not suported. Please try again with other one"
			end

			profile.Data.Inputs[context][action]["Controller"] = keybind
			return true
		else
			player:Kick("Profile load fail - Please rejoin")
		end
	elseif action == "CHANGE_MOBILE_CONTROLS" then
		local profile = profiles[player]
		if profile then
			local context = data[1] :: string
			local action = data[2] :: string
			local offset = data[3] :: {number}
			local scale = math.clamp(data[4], 0.5, 2) :: number 

			if not context or not action or not offset or not scale then
				return false, "Insufficient arguments. Please try again"
			end

			profile.Data.Inputs[context][action]["Scalar"] = scale 
			profile.Data.Inputs[context][action]["MobOffset"] = {offset[1], offset[2]}
			return true
		else
			player:Kick("Profile load fail - Please rejoin")
		end
	elseif action == "RESET_KEYBINDS" then
		local profile = profiles[player]
		if profile then
			profile.Data.Inputs = table.clone(PROFILE_TEMPLATE.Inputs)
			return true, PROFILE_TEMPLATE.Inputs
		else
			player:Kick("Profile load fail - Please rejoin")
		end
	end
end

return PlayerModule


