local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")

if not UserInputService.TouchEnabled then return end

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local Controllers = ReplicatedStorage:WaitForChild("Controllers")
local KickController = require(Controllers:WaitForChild("ShootingController"))
local StaminaController = require(Controllers:WaitForChild("StaminaController"))

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer.PlayerGui

local ballEvent: RemoteEvent = Remotes:WaitForChild("BallEvent")
local kickAnimation: Animation = ReplicatedStorage:WaitForChild("Animations"):WaitForChild("Kick")

local mobileUIFrame: Frame = playerGui:WaitForChild("Mobile"):WaitForChild("Frame")

local cooldown = false
local sprinting = false
local shiftlockEnabled = false

local camera = workspace.CurrentCamera
local camOffset = CFrame.new(1.75, 0, 0)

mobileUIFrame.Visible = true

function OnStep()
	if shiftlockEnabled then
		UserGameSettings.RotationType = Enum.RotationType.CameraRelative

		if camera then
			--Offsets the player if they aren't in first person.
			if (camera.Focus.Position - camera.CFrame.Position).Magnitude >= 0.99 then
				camera.CFrame = camera.CFrame * camOffset
				camera.Focus = CFrame.fromMatrix(camera.Focus.Position, camera.CFrame.RightVector, camera.CFrame.UpVector) * camOffset
			end
		end
	else
		UserGameSettings.RotationType = Enum.RotationType.MovementRelative
	end
end

RunService:BindToRenderStep("Mobile/ConsoleShiftLock",Enum.RenderPriority.Camera.Value+1,OnStep)

function handleShooting(shoot: "L Click" | "R Click" | "L/R Click", direction: Vector3)
	cooldown = false
	local power = KickController:GetPower()
	KickController:SetState(false)
	ballEvent:FireServer("Shoot", {
		Shoot = shoot,
		Power = power,
		Direction = direction
	})

	if not localPlayer.Character or not localPlayer.Character:FindFirstChild("Humanoid") then return end
	localPlayer.Character.Humanoid.Animator:LoadAnimation(kickAnimation):Play()
end

for index, button: TextButton | ImageButton in pairs(mobileUIFrame:GetChildren()) do
	if button.Name:find("Click") then
		button.MouseButton1Down:Connect(function()
			if cooldown then return end
			cooldown = true
			KickController:SetState(true)
		end)
		
		button.MouseButton1Up:Connect(function()
			if not cooldown then return end
			local direction = workspace.CurrentCamera.CFrame.LookVector
			handleShooting(button.Name, direction)
		end)
	elseif button.Name == "Sprint" then
		button.MouseButton1Click:Connect(function()
			sprinting = not sprinting
			button.BackgroundColor3 = sprinting and Color3.fromRGB(0, 170, 0) or Color3.new(1, 0, 0)
			
			if sprinting then
				StaminaController:Sprint()
			else
				StaminaController:StopSprint()
			end
		end)
	elseif button.Name == "Shiftlock" then
		button.MouseButton1Click:Connect(function()
			shiftlockEnabled = not shiftlockEnabled
		end)
	end
end