local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer :: Player
local inputFolder = localPlayer:WaitForChild("InputSystem", math.huge) :: Folder

local playerGui = localPlayer.PlayerGui

local mobileUI = playerGui:WaitForChild("Mobile")
local indicatorMain = playerGui:WaitForChild("Indicator"):WaitForChild("Main") :: Frame

local InputSystem ={
	Contexts = {
		Golkeeper = inputFolder:WaitForChild("Goalkeeper") :: InputContext,
		Physical = inputFolder:WaitForChild("Physical") :: InputContext,
		["Throw Tool"] = inputFolder:WaitForChild("Throw Tool") :: InputContext,
		["Hands"] = inputFolder:WaitForChild("Hands") :: InputContext,
		["Referee General"] = inputFolder:WaitForChild("Referee General") :: InputContext,
		["Spawn Tool"] = inputFolder:WaitForChild("Spawn Tool") :: InputContext,
		["Set Piece Tool"] = inputFolder:WaitForChild("Set Piece Tool") :: InputContext,
		["Penalty Tool"] = inputFolder:WaitForChild("Penalty Tool") :: InputContext,
		["General"] = inputFolder:WaitForChild("General") :: InputContext
	},
	Actions = {
		Goalkeeper = {
			["Left Predict"] = inputFolder:WaitForChild("Goalkeeper"):WaitForChild("Left Predict") :: InputAction,
			["Right Predict"] = inputFolder:WaitForChild("Goalkeeper"):WaitForChild("Right Predict") :: InputAction
		},
		Physical = {
			Sprint = inputFolder:WaitForChild("Physical"):WaitForChild("Sprint") :: InputAction
		},
		["Throw Tool"] = {
			["Fake Throw"] = inputFolder:WaitForChild("Throw Tool"):WaitForChild("Fake Throw") :: InputAction,
			Throw = inputFolder:WaitForChild("Throw Tool"):WaitForChild("Throw") :: InputAction,
			Tackle = inputFolder:WaitForChild("Throw Tool"):WaitForChild("Tackle") :: InputAction
		},
		Hands = {
			["Switch Hand"] = inputFolder:WaitForChild("Hands"):WaitForChild("Switch Hand") :: InputAction
		},
		["Referee General"] = {
			["Remove balls"] = inputFolder:WaitForChild("Referee General"):WaitForChild("Remove balls") :: InputAction
		},
		["Spawn Tool"] = {
			Spawn = inputFolder:WaitForChild("Spawn Tool"):WaitForChild("Spawn") :: InputAction,
			["Remove balls"] = inputFolder:WaitForChild("Spawn Tool"):WaitForChild("Remove balls") :: InputAction
		},
		["Set Piece Tool"] = {
			Spawn = inputFolder:WaitForChild("Set Piece Tool"):WaitForChild("Spawn") :: InputAction,
			["Change Team"] = inputFolder:WaitForChild("Set Piece Tool"):WaitForChild("Change Team") :: InputAction
		},
		["Penalty Tool"] = {
			Spawn = inputFolder:WaitForChild("Penalty Tool"):WaitForChild("Spawn") :: InputAction,
			["Change Team"] = inputFolder:WaitForChild("Penalty Tool"):WaitForChild("Change Team") :: InputAction
		},
		["General"] = {
			Shiftlock = inputFolder:WaitForChild("General"):WaitForChild("Shiftlock") :: InputAction
		}
	}
}

function InputSystem:GetPresumedButtonSize()
	local minAxis = math.min(workspace.CurrentCamera.ViewportSize.X, workspace.CurrentCamera.ViewportSize.Y)
	local presumedSize = 40

	if minAxis >= 370 then
		presumedSize = 44
	end
	if minAxis >= 600 then
		presumedSize = 72
	end
	if minAxis >= 765 then
		presumedSize = 88
	end
	
	return presumedSize
end

local function PreferredInputChanged()
	local preferredInput = UserInputService.PreferredInput
	if preferredInput == Enum.PreferredInput.Touch then
		-- MOBILE
		localPlayer:SetAttribute("Mobile", true)
		localPlayer:SetAttribute("Gamepad", false)
		
		InputSystem.Actions.Physical.Sprint.Enabled = false
	elseif preferredInput == Enum.PreferredInput.Gamepad then
		-- CONSOLE 
		localPlayer:SetAttribute("Mobile", false)
		localPlayer:SetAttribute("Gamepad", true)
	else 
		-- KEYBOARD		
		localPlayer:SetAttribute("Mobile", false)
		localPlayer:SetAttribute("Gamepad", false)
		
		InputSystem.Actions.Physical.Sprint.Enabled = true
	end

	mobileUI.Enabled = localPlayer:GetAttribute("Mobile")
	
	local keybindShowerUI = playerGui:WaitForChild("Classic")
	keybindShowerUI.Enabled = not localPlayer:GetAttribute("Mobile")
end

PreferredInputChanged()
UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(PreferredInputChanged)

function onContextEnableChange(v: InputContext)
	for u, w in InputSystem.Actions[v.Name] do
		local inputAction = w :: InputAction
		local mobileBinding = w:FindFirstChild("Mobile") :: InputBinding
		if mobileBinding then
			mobileBinding.UIButton.Parent.Visible = v.Enabled
		end
	end
end

for i, v in InputSystem.Contexts do
	local context = v :: InputContext
	coroutine.wrap(onContextEnableChange)(context)
	context:GetPropertyChangedSignal("Enabled"):Connect(function()
		coroutine.wrap(onContextEnableChange)(context)
	end)
end

function resizeButtons(v: InputContext)
	local presumedSize = InputSystem:GetPresumedButtonSize()


	for u, w in InputSystem.Actions[v.Name] do
		local inputAction = w :: InputAction
		local mobileBinding = w:FindFirstChild("Mobile") :: InputBinding
		if mobileBinding and mobileBinding.UIButton then
			local presumedUI = mobileBinding.UIButton.Parent
			local scalar = presumedUI:GetAttribute("Scalar") or 1
			local offsetPos = UDim2.fromOffset(presumedUI:GetAttribute("PosOffsetX") or 0, presumedUI:GetAttribute("PosOffsetY") or 0)
			
			presumedUI.Size = UDim2.fromOffset(presumedSize * scalar, presumedSize * scalar)
			presumedUI.Position += offsetPos
		end
	end
end

function checkSizeContext()
	local minAxis = math.min(workspace.CurrentCamera.ViewportSize.X, workspace.CurrentCamera.ViewportSize.Y)
	local presumedSize = 120
	
	if minAxis >= 600 then
		presumedSize = 220
	end
	
	if localPlayer:GetAttribute("Mobile") == true then
		indicatorMain.Size = UDim2.fromOffset(presumedSize, 0)
	end
	for i, v in InputSystem.Contexts do
		local context = v :: InputContext
		coroutine.wrap(resizeButtons)(context)
	end
end

coroutine.wrap(checkSizeContext)()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	if mobileUI.Enabled then
		coroutine.wrap(checkSizeContext)()
	end
end)


return InputSystem