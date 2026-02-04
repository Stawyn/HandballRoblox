--!nocheck
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local modules = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Systems")
local localPlayer = Players.LocalPlayer

for _, v in modules:GetChildren() do
	if v:IsA("ModuleScript") then
		require(v)
	end
end

function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid

	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
end

-- Raposa: Device Detection
task.spawn(function()
	local UserInputService = game:GetService("UserInputService")
	local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	local deviceEmoji = if isMobile then "📱" else "🖥️"

	local network = ReplicatedStorage:WaitForChild("Network")
	local playerData = network:WaitForChild("PlayerData")
	local setDevice = playerData:FindFirstChild("SetDevice")
	if not setDevice then
		-- Se nao existir, provavelmente sera criado pelo servidor, vamos esperar um pouco
		setDevice = playerData:WaitForChild("SetDevice", 10)
	end

	if setDevice and setDevice:IsA("RemoteEvent") then
		setDevice:FireServer(deviceEmoji)
	end
end)

local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
coroutine.wrap(onCharacterAdded)(character)
localPlayer.CharacterAdded:Connect(onCharacterAdded)

