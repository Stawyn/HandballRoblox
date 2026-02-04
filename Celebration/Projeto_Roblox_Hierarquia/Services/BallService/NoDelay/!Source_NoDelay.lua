local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HTTPService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local Utils = ReplicatedStorage:WaitForChild("Utils")
local Maid = require(Utils:WaitForChild("Maid"))

local ghostBall = script.Ghost

return function(BallInstance: BasePart)
	local RealtimeMaid = Maid.new()
	local noDelayBall = ghostBall:Clone()
	noDelayBall.Name = HTTPService:GenerateGUID()
	noDelayBall.Parent = workspace:WaitForChild("Core"):WaitForChild("NoDelay")
	
	BallInstance:GetPropertyChangedSignal("Parent"):Connect(function()
		if not BallInstance:IsDescendantOf(workspace) then
			RealtimeMaid:Destroy()
			if noDelayBall then
				noDelayBall:Destroy()
			end
		end
	end)
	
	RealtimeMaid:GiveTask(RunService.Stepped:Connect(function()
		local goal = {}
		goal.Position = BallInstance.Position
		
		TweenService:Create(noDelayBall, TweenInfo.new(.125), goal):Play()
	end))
end
