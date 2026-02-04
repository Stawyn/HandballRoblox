local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ThrowTool = {}
local ClientNetwork = require("../../Implementation/ClientNetwork")
local Maid = require("../../../Utilities/Maid")
local FixedThrowPower = require("../../../Modules/Implementation/ThrowPower")
local PowerUI = require("../../../Modules/Implementation/PowerUI")
local Animations = require("../../../Utilities/ABHAnimations")
local VectorLib = require("../../../Utilities/Vector")
local InputSystem = require("../../Implementation/InputSystem")

local TIME_TILL_POWER_REACHES_FULL = 0.5
local GAIN_RATE = 100 / TIME_TILL_POWER_REACHES_FULL

local charging = false

local localPlayer = Players.LocalPlayer :: Player

function CheckToolEquipped(tool: Tool): boolean
	local backpack = localPlayer.Backpack
	local character = localPlayer.Character
	if not character then
		return false
	end

	if backpack:FindFirstChild("ThrowTool") then
		return true
	end

	if character:FindFirstChild("ThrowTool") then
		return true
	end

	return false
end

function ThrowTool:GetCharging()
	return charging
end

function ThrowTool:Initialize(tool: Tool)	
	local power = 0
	-- local charging = false
	local uiCooldown = false
	local throwMaid = Maid.new()
	local keybindMaid = Maid.new()
	local powerMaid = Maid.new()
	local switchHandsCooldown = false
	local chargingThrowAnimation = nil :: AnimationTrack?
	local tackleCooldown = false

	local function setCharging(state: boolean)
		local character = localPlayer.Character
		if not character then
			charging = state
			return
		end

		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		local animator = humanoid:WaitForChild("Animator") :: Animator

		if not state then
			if chargingThrowAnimation then
				chargingThrowAnimation:Stop()
			end
		else
			local currentHand = localPlayer:GetAttribute("CurrentHand")
			local animationToLoad
			if currentHand == "R" then
				animationToLoad = Animations.RHandChargeThrow
			else
				animationToLoad = Animations.LHandChargeThrow
			end

			chargingThrowAnimation = animator:LoadAnimation(animationToLoad)
			chargingThrowAnimation:Play()
		end

		charging = state
	end

	local function playThrowAnimation()
		local character = localPlayer.Character
		if not character then
			return
		end

		local currentHand = localPlayer:GetAttribute("CurrentHand")
		local animator = character:WaitForChild("Humanoid"):WaitForChild("Animator") :: Animator

		local throwAnimation
		if currentHand == "R" then
			throwAnimation = Animations.RHandThrow
		else
			throwAnimation = Animations.LHandThrow
		end

		local animationTrack = animator:LoadAnimation(throwAnimation)
		animationTrack:Play()
	end

	local function checkToolEquipped()
		if not localPlayer.Character then 
			return false
		end
		if not localPlayer.Character:FindFirstChild("ThrowTool") then
			return false
		end

		return true
	end

	local function handleThrow()
		if not checkToolEquipped() then
			return
		end
		if not charging then
			return
		end

		local character = localPlayer.Character
		if not character then
			return
		end
		if not character:FindFirstChild("BallOwnership") then
			return
		end

		local humanoidRoortPart = character:FindFirstChild("HumanoidRootPart") :: BasePart

		local hrpPosition = humanoidRoortPart.Position
		local mousePosition = localPlayer:GetMouse().Hit.LookVector

		local mouseDirection = localPlayer:GetMouse().UnitRay.Direction
		if localPlayer:GetAttribute("Mobile") == true then
			-- Mobile doesnt have mouse
			mouseDirection = workspace.CurrentCamera.CFrame.LookVector
			mousePosition = mouseDirection
		end

		local direction = humanoidRoortPart.CFrame.LookVector
		ClientNetwork.ThrowEvent:Throw(power, {
			humanoidRootPartDirection = vector.create(direction.X, direction.Y, direction.Z),
			mouseDirection = vector.create(mouseDirection.X, mouseDirection.Y, mouseDirection.Z),
			mousePosition = vector.create(mousePosition.X, mousePosition.Y, mousePosition.Z),
			humanoidRootPartPosition = vector.create(hrpPosition.X, hrpPosition.Y, hrpPosition.Z)
		})
		playThrowAnimation()
	end

	tool.Equipped:Connect(function()
		InputSystem.Contexts["Throw Tool"].Enabled = true 

		keybindMaid:GiveTask(InputSystem.Actions["Throw Tool"].Throw.Pressed:Connect(function()
			setCharging(true)
			uiCooldown = true
		end))
		keybindMaid:GiveTask(InputSystem.Actions["Throw Tool"].Throw.Released:Connect(function()
			if not uiCooldown then 
				return
			end

			handleThrow()
			setCharging(false)
			power = 0
			uiCooldown = false
		end))

		keybindMaid:GiveTask(InputSystem.Actions["Throw Tool"].Tackle.Pressed:Connect(function()
			if localPlayer.Character and localPlayer.Character:FindFirstChild("BallOwnership") then
				return
			end
			if tackleCooldown then 
				return
			end
			if charging then 
				return
			end

			tackleCooldown = true
			ClientNetwork.TacklingFunction:Tackle()
			tackleCooldown = false
		end))

		keybindMaid:GiveTask(InputSystem.Actions["Throw Tool"]["Fake Throw"].Pressed:Connect(function()
			if not uiCooldown then
				return
			end

			setCharging(false)
			if localPlayer.Character and localPlayer.Character:FindFirstChild("BallOwnership") then
				playThrowAnimation()
			end
			uiCooldown = false
		end))
	end)

	tool.Unequipped:Connect(function()
		InputSystem.Contexts["Throw Tool"].Enabled = false

		throwMaid:DoCleaning()
		keybindMaid:DoCleaning()
		charging = false
		if chargingThrowAnimation then
			chargingThrowAnimation:Stop()
		end

		if localPlayer.Character and localPlayer.Character:FindFirstChild("BallOwnership") then
			ClientNetwork.BallEvents:DropRequest()
		end
	end)

	tool.Destroying:Connect(function()
		throwMaid:DoCleaning()
		keybindMaid:DoCleaning()
		powerMaid:DoCleaning()
	end)

	powerMaid:GiveTask(RunService.Heartbeat:Connect(function(deltaTime)
		if charging then
			if power < 100 then
				power += GAIN_RATE * deltaTime
				power = math.clamp(power, 0, 100)
			end
		else
			if power ~= 0 then
				power = 0
			end
		end

		-- Direct property setting is faster than Tweening every heartbeat
		local mouseDirection = VectorLib:Vector3ToVectorLib(localPlayer:GetMouse().UnitRay.Direction)
		local mousePosition = VectorLib:Vector3ToVectorLib(localPlayer:GetMouse().Hit.LookVector)

		local character = localPlayer.Character
		if character and character:FindFirstChild("HumanoidRootPart") then
			local hrp = character.HumanoidRootPart
			local fixedPower = FixedThrowPower(mouseDirection, mousePosition, VectorLib:Vector3ToVectorLib(hrp.CFrame.LookVector), power, hrp.Position, localPlayer)

			PowerUI:UpdatePower(power, fixedPower)
		end
	end))
end



return ThrowTool

