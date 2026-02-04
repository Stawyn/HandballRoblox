local PlayerTypes = require(game:GetService("ReplicatedStorage"):WaitForChild("Types"):WaitForChild("PlayerTypes"))
local grip: CFrame = CFrame.new(0,-2,-1.5)
local keeperGrip: CFrame = CFrame.new(-1.1,-1.25,0)

return function(BallInstance: MeshPart, Character: PlayerTypes.Character)
	local newWeld: Weld = Instance.new("Weld")
	newWeld.Name = "BallWeld"
	newWeld.Part0 = BallInstance
	newWeld.Part1 = Character.HumanoidRootPart
	newWeld.C1 = grip
	newWeld.Parent = Character.HumanoidRootPart	
end
