local RefereeController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maid = require(ReplicatedStorage:WaitForChild("Utils"):WaitForChild("Maid"))

local statsFolder: Folder = workspace:WaitForChild("Core"):WaitForChild("Stats")

local RefereeEvent: RemoteEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Referee")

function RefereeController:SetGoal(properties)
	RefereeEvent:FireServer("SetGoal", properties)
end

function RefereeController:StartTimer(state)
	RefereeEvent:FireServer("Timer", state)
end

function RefereeController:ResetTimer()
	RefereeEvent:FireServer("ResetTimer")
end

function RefereeController:SetET(quantity)
	RefereeEvent:FireServer("SetET", quantity)
end

function RefereeController:ResetET()
	RefereeEvent:FireServer("ResetET")
end

function RefereeController:ResetScores()
	RefereeEvent:FireServer("ResetScores")
end

function RefereeController:SetAbbreviation(properties: SetAbbreviationProperties)
	RefereeEvent:FireServer("SetAbbreviation", properties)
end

function RefereeController:SetMatchValue(value)
	RefereeEvent:FireServer("SetMatchValue", value)
end

return RefereeController
