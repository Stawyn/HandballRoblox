local LocalizationService = game:GetService("LocalizationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HTTPService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")

local CoinsData = DataStoreService:GetDataStore("CoinsData")
local CountryModule = require(script.CountryAPI)

local pingEvent: RemoteFunction = ReplicatedStorage:WaitForChild("RemoteFunctions"):WaitForChild("Ping")

function OnPlayerJoined(player: Player)
	local playerCoins = nil
	player:SetAttribute("SetPiece", false)

	local leaderstats: Folder = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local pingValue: NumberValue = Instance.new("NumberValue")
	pingValue.Name = "Ping"
	pingValue.Parent = leaderstats
	
	local Coins: NumberValue = Instance.new("NumberValue")
	Coins.Name = "Coins"
	Coins.Parent = leaderstats

	local country: StringValue = Instance.new("StringValue")
	country.Name = "Country"
	country.Parent = leaderstats

	local team: StringValue = Instance.new("StringValue")
	team.Name = "Team"
	team.Value = "F/A"
	team.Parent = leaderstats

	local suspended: StringValue = Instance.new("BoolValue")
	suspended.Name = "Suspended"
	suspended.Value = false
	suspended.Parent = leaderstats

	local staff: BoolValue = Instance.new("BoolValue")
	staff.Name = "Staff"
	staff.Value = false
	staff.Parent = leaderstats
	
	country.Value = LocalizationService:GetCountryRegionForPlayerAsync(player)
	
	local success, err = pcall(function()
		playerCoins = CoinsData:GetAsync(player.UserId)
	end)
	
	if success then
		Coins.Value = playerCoins or 100
	elseif not success and err then
		warn("Failed to get "..player.Name.." coins. \ncause: "..tostring(err))
	end
	
	while player:IsDescendantOf(Players) do
		local lastTime: number = os.clock()
		local sucess, received = pcall(function()
			return pingEvent:InvokeClient(player, "Ping")
		end)
		local calculations: number = os.clock() - lastTime
		local difference: number = math.floor(calculations * 1e3)
		pingValue.Value = difference
		task.wait(1)
	end
end

Players.PlayerRemoving:Connect(function(player)
	local coinsValue = player.leaderstats.Coins.Value
	local success, err = pcall(function()
		CoinsData:SetAsync(player.UserId, coinsValue)
	end)
	
	if success then
		print(tostring(coinsValue).." has been saved to "..player.Name)
	elseif not success and err then
		warn("Failed to save "..player.Name.." coins, \ncause: "..tostring(err))
	end
end)

for _, player: Player in pairs(Players:GetPlayers()) do
	task.spawn(OnPlayerJoined, player)
end

Players.PlayerAdded:Connect(OnPlayerJoined)
