local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SetPiece = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SetPiece")
local Keeper = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Keeper")

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.T then
		SetPiece:FireServer()
	elseif input.KeyCode == Enum.KeyCode.Y then
		Keeper:FireServer("Keeper")
	end
end)
