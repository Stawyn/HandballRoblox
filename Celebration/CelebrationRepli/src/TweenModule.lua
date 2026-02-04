local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local TweenModule = {}

local localPlayer = Players.LocalPlayer

local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()

local head = character:WaitForChild("Head")
local rightArm = character:WaitForChild("Right Arm")
local leftArm = character:WaitForChild("Left Arm")
local rightLeg = character:WaitForChild("Right Leg")
local leftLeg = character:WaitForChild("Left Leg")

function TweenModule:ResetWelds()
	local torso: BasePart = character:WaitForChild("Torso")

	for index, weld: Weld in pairs(torso:GetChildren()) do
		if weld:IsA("Weld") and weld.Name ~= "TDragger" then
			weld:Destroy()
		end
	end

	local leftShoulder = torso:FindFirstChild("Left Shoulder")
	local rightShoulder = torso:FindFirstChild("Right Shoulder")
	local leftHip = torso:FindFirstChild("Left Hip")
	local rightHip = torso:FindFirstChild("Right Hip")
	local neck = torso:FindFirstChild("Neck")

	local joins = {leftShoulder, rightShoulder, rightHip, neck}
	local correspondingLimbs = {leftArm, rightArm, leftLeg, head}

	for index, limbs: Weld in pairs(joins) do
		limbs.Part1 = correspondingLimbs[index]
	end
end

function TweenModule:TweenWelds(targetLimb: string, startCFrame: CFrame, cframe0: CFrame)
	local torso: BasePart = character:WaitForChild("Torso")
	
	local existingWeld = nil
	local appendiges = {rightArm, leftArm, rightLeg, leftLeg, head}	
	local correspondingJoints = {
		torso:FindFirstChild("Right Shoulder"),
		torso:FindFirstChild("Left Shoulder"),
		torso:FindFirstChild("Right Hip"),
		torso:FindFirstChild("Left Hip"),
		torso:FindFirstChild("Necl")
	}
	
	local endCFrame = {}
	endCFrame.C0 = cframe0
	
	local tweenInformation = TweenInfo.new(
		0.4,
		Enum.EasingStyle.Back,
		Enum.EasingDirection.Out
	)
	
	for index, weld: Weld in pairs(torso:GetChildren()) do
		if weld:IsA("Weld") and weld.Part1.Name == targetLimb then
			existingWeld = weld
		end
	end
	
	if not existingWeld then
		existingWeld = Instance.new("Weld")
	end
	
	for index, appendige in pairs(appendiges) do
		if targetLimb == appendige.Name then
			correspondingJoints[index].Part1 = nil
			
			existingWeld.Parent = torso
			existingWeld.Part0 = torso
			existingWeld.Part1 = appendige
			existingWeld.C0 = startCFrame
			TweenService:Create(existingWeld, tweenInformation, endCFrame):Play()
		end
	end
end

function TweenModule:EditWeld(targetLimb: string, cframe0: CFrame, cframe1: CFrame)
	local torso: BasePart = character:WaitForChild("Torso")

	local existingWeld = nil
	local appendiges = {rightArm, leftArm, rightLeg, leftLeg, head}	
	local correspondingJoints = {
		torso:FindFirstChild("Right Shoulder"),
		torso:FindFirstChild("Left Shoulder"),
		torso:FindFirstChild("Right Hip"),
		torso:FindFirstChild("Left Hip"),
		torso:FindFirstChild("Necl")
	}

	local endCFrame = {}
	endCFrame.C0 = cframe0

	local tweenInformation = TweenInfo.new(
		0.4,
		Enum.EasingStyle.Back,
		Enum.EasingDirection.Out
	)

	for index, weld: Weld in pairs(torso:GetChildren()) do
		if weld:IsA("Weld") and weld.Part1.Name == targetLimb then
			existingWeld = weld
		end
	end

	if not existingWeld then
		existingWeld = Instance.new("Weld")
	end

	for index, appendige in pairs(appendiges) do
		if targetLimb == appendige.Name then
			if not correspondingJoints[index] then repeat task.wait() until correspondingJoints[i] end
			correspondingJoints[index].Part1 = nil

			existingWeld.Parent = torso
			existingWeld.Part0 = torso
			existingWeld.Part1 = appendige
			existingWeld.C0 = cframe0
			if cframe1 ~= nil then
				existingWeld.C1 = cframe1
			end
		end
	end
end

return TweenModule