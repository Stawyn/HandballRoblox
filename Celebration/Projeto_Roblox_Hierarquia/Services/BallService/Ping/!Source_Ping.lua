type BallObject = {
	Instance: BasePart,
	CanTouch: boolean,
	Data: {
		["LastShoot"]: ObjectValue,
		["PlayerOnBall"]: ObjectValue,
		["LastShootShoot"]: ObjectValue,
		["LastPlayerOnBall"]: ObjectValue
	}
}

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HTTPService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local Utils = ReplicatedStorage:WaitForChild("Utils")
local Maid = require(Utils:WaitForChild("Maid"))

return function(BallModel: BallObject)
	local changedPingMaid = Maid.new()
	
	local ballOwner: Player? = nil
	local oldPings = {}
	local playerOnBall = BallModel.Data.PlayerOnBall
	local lastPlayerOnBall = BallModel.Data.LastPlayerOnBall

	BallModel.Instance:GetPropertyChangedSignal("Parent"):Connect(function()
		if not BallModel.Instance:IsDescendantOf(workspace) then
			changedPingMaid:Destroy()
		end
	end)

	local function formatString(tbl: {number}, playerName: string): string
		local formattedString		

		if tbl[3] then
			formattedString = ("%sms, %sms, %sms"):format(tbl[1], tbl[2], tbl[3])
		elseif tbl[2] then
			formattedString = ("%sms, %sms"):format(tbl[1], tbl[2])
		else
			formattedString = ("%sms"):format(tbl[1])
		end

		local finalString = ("%s - %s"):format(playerName, formattedString)

		return finalString
	end

	local function handlePingTable(ping: number, playerName: string)
		if #oldPings < 3 then
			table.insert(oldPings, ping)
		else
			local newThirdPing = oldPings[2]
			local newSecondPing = oldPings[1]
			oldPings[3] = nil
			oldPings[3] = newThirdPing
			oldPings[2] = newSecondPing
			oldPings[1] = ping
		end

		local formattedString = formatString(oldPings, playerName)
		BallModel.Instance.Ping.Value = formattedString
	end

	local function HandleExistingPlayerOnBall(currentPlayerOnBall: Player)
		changedPingMaid:Destroy()
		local playerPing: NumberValue = currentPlayerOnBall.leaderstats.Ping
		handlePingTable(playerPing.Value, currentPlayerOnBall.Name)
		changedPingMaid:GiveTask(playerPing:GetPropertyChangedSignal("Value"):Connect(function()
			handlePingTable(playerPing.Value, currentPlayerOnBall.Name)
		end))
	end


	playerOnBall:GetPropertyChangedSignal("Value"):Connect(function()
		local currentPlayerOnBall = playerOnBall.Value
		if not currentPlayerOnBall then 
			changedPingMaid:Destroy()
			return 
		end

		if currentPlayerOnBall and lastPlayerOnBall.Value and currentPlayerOnBall.Name ~= lastPlayerOnBall.Value.Name then
			changedPingMaid:Destroy()
			table.clear(oldPings)
		end

		if currentPlayerOnBall then
			HandleExistingPlayerOnBall(currentPlayerOnBall)
		end
	end)
end
