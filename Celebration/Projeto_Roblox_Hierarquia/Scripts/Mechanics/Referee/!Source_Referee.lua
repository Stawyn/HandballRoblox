local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RefereeService = require(ServerScriptService:WaitForChild("Services"):WaitForChild("RefereeService"))
local RefereeEvent: RemoteEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Referee")

RefereeEvent.OnServerEvent:Connect(function(player: Player, event: string, ...)
	if player.TeamColor ~= BrickColor.new("Bright green") then return end
	
	if event == "SetGoal" then
		local givenProps = ...
		RefereeService:SetGoal(givenProps)
	elseif event == "Timer" then
		local givenState = ...
		RefereeService:SetTimerState(givenState)
	elseif event == "SetET" then
		local givenET = ...
		RefereeService:SetET(givenET)
	elseif event == "ResetET" then
		RefereeService:ResetET()
	elseif event == "ResetScores" then
		RefereeService:ResetScores()
	elseif event == "ResetTimer" then
		RefereeService:ResetTimer()
	elseif event == "SetAbbreviation" then
		local givenProps = ...
		RefereeService:SetAbbreviation(givenProps)
	elseif event == "SetMatchValue" then
		local givenValue = ...
		RefereeService:SetMatchValue(givenValue)
	end
end)
