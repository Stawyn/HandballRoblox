local dss = game:GetService("DataStoreService")
local ds = dss:GetDataStore("EmotesDS")


local repl = game.ReplicatedStorage:WaitForChild("EmotesSource")
local re = repl:WaitForChild("RE")
local allEmotes = repl:WaitForChild("Emotes")


--Saving data
function save(plr)
	
	local Coins = plr.leaderstats.Coins.Value
	
	local ownedEmotes = plr.Emotes:GetChildren()
	local emoteNames = {}
	
	for i, emote in pairs(ownedEmotes) do
		table.insert(emoteNames, emote.Name)
	end
	
	local combinedData = {Coins, emoteNames}
	
	ds:SetAsync(plr.UserId, combinedData)
end

game.Players.PlayerRemoving:Connect(save)

game:BindToClose(function()
	
	for i, plr in pairs(game.Players:GetPlayers()) do
		save(plr)
	end
end)


--Loading data
game.Players.PlayerAdded:Connect(function(plr)

	local emotesF = Instance.new("Folder")
	emotesF.Name = "Emotes"
	emotesF.Parent = plr
	
	local data = ds:GetAsync(plr.UserId) or {1000, {}}
	
	for i, emote in pairs(data[2]) do
		
		if allEmotes:FindFirstChild(emote) then
			allEmotes[emote]:Clone().Parent = emotesF
		end
	end
end)


--Handling purchases
re.OnServerEvent:Connect(function(plr, emoteN)
	
	if emoteN and allEmotes:FindFirstChild(emoteN) and allEmotes[emoteN]:FindFirstChild("PRICE") then
		
		local price = allEmotes[emoteN].PRICE.Value
		local pCash = plr.leaderstats.Coins
		
		local pEmotes = plr.Emotes
		
		if pCash.Value >= price and not pEmotes:FindFirstChild(emoteN) then
			pCash.Value -= price
			
			allEmotes[emoteN]:Clone().Parent = pEmotes
		end
	end
end)
