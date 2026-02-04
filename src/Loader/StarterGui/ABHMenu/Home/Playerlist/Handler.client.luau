local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")

local Implementation = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Implementation")
local Utilities = ReplicatedStorage:WaitForChild("Utilities")

local ClientNetwork = require(Implementation:WaitForChild("ClientNetwork"))
local InputSystem = require(Implementation:WaitForChild("InputSystem"))
local Janitor = require(Utilities:WaitForChild("Janitor"))
local Slider = require(Utilities:WaitForChild("Slider"))
local IconSet = require(Utilities:WaitForChild("Kenney"))
local Icon = require(Utilities:WaitForChild("Icon"))

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer.PlayerGui

local playerlist = script.Parent
local home = playerlist.Parent
local abhMenu = home.Parent

local interactions = playerlist:WaitForChild("Interactions")
local list = interactions:WaitForChild("List")
local keybindFolder = interactions:WaitForChild("KeybindHandler")
local keybindTemplate = keybindFolder:WaitForChild("KeybindTemplate")

local listTitle = list:WaitForChild("Title")
local toggleStadium = list:WaitForChild("Toogle Stadium")
local toggleMobileEdit = list:WaitForChild("ToggleMobileEdit")
local resetControls = list:WaitForChild("ResetKeybinds")
local closeSettings = list:WaitForChild("Close")

local blur = Lighting:WaitForChild("Blur")
local editingFrame = home:WaitForChild("Editing")
local editingTitle = editingFrame:WaitForChild("Title")
local sliderHolder = editingFrame:WaitForChild("SliderContainer"):WaitForChild("SliderHolder")
local sliderButton = sliderHolder:WaitForChild("slider")
local readyButton = editingFrame:WaitForChild("Ready")
local cancelButton = editingFrame:WaitForChild("Cancel")
local exitButton = editingFrame:WaitForChild("Exit")
local promptText = abhMenu:WaitForChild("Prompt")

local mobileUI = playerGui:WaitForChild("Mobile")

local stadiumRemoved = false
local cooldown = false

local editJanitor = Janitor.new()
local confirmJanitor = Janitor.new()
local selectedFrame: Frame? = nil
local selectedDefaultColor: Color3? = nil
local previousSize: UDim2? = nil
local previousPosition: UDim2? = nil
local referenceUI: ScreenGui? = nil
local contextButtons: {GuiObject} = {}
local contextListState: {[Instance]: boolean} = {}
local contextMenuOpen = false
local keybindItems: {GuiObject} = {}
local gamepadItems: {GuiObject} = {}

local slider = Slider.new(sliderButton, {
	values = {min = 50, max = 200},
	defaultValue = 100,
	canLeaveFrame = false,
	canFullyLeaveFrame = false,
	moveToMouse = true,
})

local function clearSelectedFrame(revertChanges: boolean)
	if not selectedFrame then
		return
	end

	if selectedFrame:FindFirstChild("UIDragDetector") then
		selectedFrame.UIDragDetector:Destroy()
	end
	confirmJanitor:Cleanup()

	if revertChanges then
		if previousPosition then
			selectedFrame.Position = previousPosition
		end
		if previousSize then
			selectedFrame.Size = previousSize
		end
	end

	if selectedDefaultColor then
		selectedFrame.BackgroundColor3 = selectedDefaultColor
	end

	local interact = selectedFrame:FindFirstChild("Interact")
	if interact and interact:IsA("TextButton") then
		interact.Interactable = true
	end

	selectedFrame = nil
	previousSize = nil
	previousPosition = nil
	selectedDefaultColor = nil
end

-- Aguarda o atributo Mobile ser setado
local mobileAttribute = localPlayer:GetAttribute("Mobile")
local waitCount = 0
while mobileAttribute == nil and waitCount < 50 do
	task.wait(0.1)
	mobileAttribute = localPlayer:GetAttribute("Mobile")
	waitCount = waitCount + 1
end

local function adaptDesign()
	local isMobile = localPlayer:GetAttribute("Mobile")
	local sizeConstraint = home:FindFirstChild("UISizeConstraint")
	local uiCorner = playerlist:FindFirstChild("UICorner")
	local uiStroke = playerlist:FindFirstChild("UIStroke")
	local title = playerlist:FindFirstChild("Title")
	local icon = playerlist:FindFirstChild("Icon")
	local separator = playerlist:FindFirstChild("Separator")
	local listPadding = list:FindFirstChild("UIPadding")

	if isMobile then
		home.Size = UDim2.new(1, 0, 1, 0)
		if sizeConstraint then
			sizeConstraint.Parent = nil
		end
		if uiCorner then
			uiCorner.CornerRadius = UDim.new(0, 0)
		end
		if uiStroke then
			uiStroke.Enabled = false
		end
		if title then
			title.Position = UDim2.new(0.4, 0, 0.12, 0)
		end
		if icon then
			icon.Position = UDim2.new(0.28, 0, 0.12, 0)
		end
		if separator then
			separator.Position = UDim2.new(0.5, 0, 0.2, 0)
		end
		list.Size = UDim2.new(1, 0, 0.78, 0)
		list.Position = UDim2.new(0.5, 0, 0.6, 0)
		list.ScrollBarThickness = 5
		if listPadding then
			listPadding.PaddingLeft = UDim.new(0, 20)
			listPadding.PaddingRight = UDim.new(0, 20)
			listPadding.PaddingBottom = UDim.new(0, 60)
		end
	else
		home.Size = UDim2.new(0.85, 0, 0.8, 0)
		if sizeConstraint then
			sizeConstraint.Parent = home
		end
		if uiCorner then
			uiCorner.CornerRadius = UDim.new(0, 13)
		end
		if uiStroke then
			uiStroke.Enabled = true
		end
		if title then
			title.Position = UDim2.new(0.15, 0, 0.08, 0)
		end
		if icon then
			icon.Position = UDim2.new(0.08, 0, 0.08, 0)
		end
		if separator then
			separator.Position = UDim2.new(0.5, 0, 0.13, 0)
		end
		list.Size = UDim2.new(0.95, 0, 0.8, 0)
		list.Position = UDim2.new(0.5, 0, 0.57, 0)
		list.ScrollBarThickness = 4
		if listPadding then
			listPadding.PaddingLeft = UDim.new(0, 10)
			listPadding.PaddingRight = UDim.new(0, 10)
			listPadding.PaddingBottom = UDim.new(0, 15)
		end
	end
end

local function toggleGameUI()
	local isMenuEnabled = abhMenu.Enabled
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, not isMenuEnabled)
	if Icon and Icon.setTopbarEnabled then
		Icon.setTopbarEnabled(not isMenuEnabled)
	end
	local fluxUI = playerGui:FindFirstChild("FluxUILayerTopbar")
	if fluxUI then
		fluxUI.Enabled = not isMenuEnabled
	end
	if isMenuEnabled then
		local humanoid = localPlayer.Character and localPlayer.Character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid:UnequipTools()
		end
	end
end

local function updateDeviceVisibility(keybindItems, gamepadItems)
	local isMobile = localPlayer:GetAttribute("Mobile")
	local isGamepad = localPlayer:GetAttribute("Gamepad")
	local showKeyboard = not isMobile and not isGamepad
	local showGamepad = isGamepad

	if contextMenuOpen then
		listTitle.Visible = false
		toggleMobileEdit.Visible = false
		for _, item in keybindItems do
			item.Visible = false
		end
		for _, item in gamepadItems do
			item.Visible = false
		end
		return
	end

	listTitle.Visible = showKeyboard or showGamepad
	toggleMobileEdit.Visible = isMobile
	for _, item in keybindItems do
		item.Visible = showKeyboard
	end
	for _, item in gamepadItems do
		item.Visible = showGamepad
	end
end

local function closeMobileEditMenu(keybindItems, gamepadItems)
	for _, button in contextButtons do
		if button then
			button:Destroy()
		end
	end
	contextButtons = {}

	for child, visible in contextListState do
		if child and child.Parent then
			child.Visible = visible
		end
	end
	contextListState = {}
	contextMenuOpen = false
	if keybindItems and gamepadItems then
		updateDeviceVisibility(keybindItems, gamepadItems)
	end
end

local function activateUIByContext(contextName: string, state: boolean)
	if not referenceUI then
		return
	end
	for _, child in referenceUI:GetChildren() do
		if child:IsA("Frame") and child:GetAttribute("Context") == contextName then
			child.Visible = state
		end
	end
end

local function activateUIEditByContext(contextName: string)
	editJanitor:Cleanup()
	if not referenceUI then
		return
	end
	for _, child in referenceUI:GetChildren() do
		if child:IsA("Frame") and child:GetAttribute("Context") == contextName then
			local interact = child:FindFirstChild("Interact")
			if not interact or not interact:IsA("TextButton") then
				continue
			end

			editJanitor:Add(interact.MouseButton1Click:Connect(function()
				clearSelectedFrame(true)

				local presumedSize = InputSystem:GetPresumedButtonSize()
				promptText.Visible = false
				interact.Interactable = false
				editingTitle.Text = string.format("EDITANDO: %s", child.Name:upper())

				selectedFrame = child
				selectedDefaultColor = child.BackgroundColor3
				previousSize = child.Size
				previousPosition = child.Position
				child.BackgroundColor3 = Color3.fromRGB(30, 30, 0)

				editingFrame.Visible = true
				playerlist.Visible = false

				local uiDrag = Instance.new("UIDragDetector")
				uiDrag.Parent = child

				slider:Reset()
				slider:SetValue((child:GetAttribute("Scalar") or 1) * 100)
				slider:Enable()
				confirmJanitor:Add(slider.moved:Connect(function()
					local currentScalar = slider:GetValue() / 100
					child.Size = UDim2.fromOffset(presumedSize * currentScalar, presumedSize * currentScalar)
				end))

				confirmJanitor:Add(readyButton.MouseButton1Click:Connect(function()
					slider:Disable()
					local scalar = slider:GetValue() / 100
					local offsetPosition = {child.Position.X.Offset, child.Position.Y.Offset}
					child:SetAttribute("Scalar", scalar)
					child:SetAttribute("PosOffsetX", offsetPosition[1])
					child:SetAttribute("PosOffsetY", offsetPosition[2])
					interact.Interactable = true

					pcall(function()
						ClientNetwork.PlayerDataFunction:CustomizeMobile(contextName, child.Name, offsetPosition, scalar)
					end)

					for _, realChild in mobileUI:GetChildren() do
						if realChild.Name == child.Name and realChild:GetAttribute("Context") == contextName then
							realChild.Position = child.Position
							realChild.Size = child.Size
							realChild:SetAttribute("Scalar", scalar)
							realChild:SetAttribute("PosOffsetX", offsetPosition[1])
							realChild:SetAttribute("PosOffsetY", offsetPosition[2])
							break
						end
					end

					clearSelectedFrame(false)
					editingFrame.Visible = false
					promptText.Visible = false
					playerlist.Visible = true
					if referenceUI then
						referenceUI:Destroy()
						referenceUI = nil
					end
					mobileUI.Enabled = true
					confirmJanitor:Cleanup()
					closeMobileEditMenu(keybindItems, gamepadItems)
				end))
			end))
		end
	end
end

cancelButton.MouseButton1Click:Connect(function()
	slider:Disable()
	clearSelectedFrame(true)
	editingFrame.Visible = false
	promptText.Visible = true
	playerlist.Visible = false
end)

exitButton.MouseButton1Click:Connect(function()
	slider:Disable()
	clearSelectedFrame(true)
	if referenceUI then
		referenceUI:Destroy()
		referenceUI = nil
	end
	editingFrame.Visible = false
	promptText.Visible = false
	playerlist.Visible = true
	mobileUI.Enabled = localPlayer:GetAttribute("Mobile")
	closeMobileEditMenu(keybindItems, gamepadItems)
end)

local function openMobileEditMenu(keybindItems, gamepadItems)
	if contextMenuOpen or not localPlayer:GetAttribute("Mobile") then
		return
	end
	contextMenuOpen = true

	contextListState = {}
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			contextListState[child] = child.Visible
			child.Visible = false
		end
	end

	local backButton = closeSettings:Clone()
	backButton.Name = "BackFromMobile"
	backButton.Title.Text = "VOLTAR"
	backButton.Subtitle.Text = "Retornar ao menu principal"
	backButton.LayoutOrder = -100
	backButton.Visible = true
	backButton.Parent = list
	table.insert(contextButtons, backButton)
	backButton.MouseButton1Click:Connect(function()
		closeMobileEditMenu(keybindItems, gamepadItems)
	end)

	for _, context in InputSystem.Contexts do
		if context.Name == "General" then
			continue
		end
		local btn = toggleMobileEdit:Clone()
		btn.Name = context.Name
		btn.Title.Text = context.Name:upper()
		btn.Subtitle.Text = "Editar botões da categoria " .. context.Name
		btn.Visible = true
		btn.Parent = list
		table.insert(contextButtons, btn)

		btn.MouseButton1Click:Connect(function()
			if referenceUI then
				referenceUI:Destroy()
				referenceUI = nil
			end
			referenceUI = mobileUI:Clone()
			referenceUI.Name = "MobileReference"
			referenceUI.Enabled = true
			referenceUI.Parent = playerGui

			for _, ctx in InputSystem.Contexts do
				activateUIByContext(ctx.Name, false)
			end
			activateUIByContext(context.Name, true)
			activateUIEditByContext(context.Name)

			mobileUI.Enabled = false
			playerlist.Visible = false
			editingFrame.Visible = false
			promptText.Visible = true
		end)
	end
end

keybindTemplate.Visible = false

local function getGamepadType(): string
	local buttonString = UserInputService:GetStringForKeyCode(Enum.KeyCode.ButtonA)
	if buttonString == "ButtonCross" then
		return "ps"
	end
	return "xbox"
end

local function buildKeybindLists()
	keybindItems = {}
	gamepadItems = {}

	for _, context in InputSystem.Contexts do
		for _, action in InputSystem.Actions[context.Name] do
			local template = keybindTemplate:Clone()
			template.Title.Text = action.Name
			template.Subtitle.Text = context.Name

			local changedJanitor = Janitor.new()
			local presumedInputBind = action:WaitForChild("Keyboard") :: InputBinding

			presumedInputBind:GetPropertyChangedSignal("KeyCode"):Connect(function()
				template.PlayerInteractions.Locate.KeyIcon.Image = IconSet.keyboard[presumedInputBind.KeyCode]
			end)

			template.PlayerInteractions.Locate.KeyIcon.Image = IconSet.keyboard[presumedInputBind.KeyCode]

			template.PlayerInteractions.Locate.Interact.MouseButton1Click:Connect(function()
				changedJanitor:Cleanup()

				template.PlayerInteractions.Locate.KeyIcon.Visible = false
				template.PlayerInteractions.Locate.Interact.Visible = false
				template.PlayerInteractions.Locate.LoadingEffect.Visible = true

				local thread = task.spawn(function()
					while task.wait() do
						template.PlayerInteractions.Locate.LoadingEffect.Rotation += 5
					end
				end)

				changedJanitor:Add(UserInputService.InputBegan:Connect(function(inputObject, gameProcessedEvent)
					if gameProcessedEvent then
						return
					end

					local keyCode = inputObject.KeyCode
					if action.Name ~= "Shiftlock" then
						if keyCode == Enum.KeyCode.Unknown then
							if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
								keyCode = Enum.KeyCode.MouseLeftButton
							elseif inputObject.UserInputType == Enum.UserInputType.MouseButton2 then
								keyCode = Enum.KeyCode.MouseRightButton
							elseif inputObject.UserInputType == Enum.UserInputType.MouseButton3 then
								keyCode = Enum.KeyCode.MouseMiddleButton
							end
						end
					end

					if not IconSet.keyboard[keyCode] then
						changedJanitor:Cleanup()
						template.PlayerInteractions.Locate.KeyIcon.Visible = true
						template.PlayerInteractions.Locate.Interact.Visible = true
						template.PlayerInteractions.Locate.LoadingEffect.Visible = false
						task.cancel(thread)
						return
					end

					changedJanitor:Cleanup()
					task.cancel(thread)
					local success = ClientNetwork.PlayerDataFunction:ChangeKeybind(context.Name, action.Name, keyCode.Name)
					if success then
						presumedInputBind.KeyCode = keyCode
						template.PlayerInteractions.Locate.KeyIcon.Image = IconSet.keyboard[keyCode]
					end

					template.PlayerInteractions.Locate.KeyIcon.Visible = true
					template.PlayerInteractions.Locate.Interact.Visible = true
					template.PlayerInteractions.Locate.LoadingEffect.Visible = false
				end))
			end)

			template.Parent = list
			table.insert(keybindItems, template)
		end
	end

	for _, context in InputSystem.Contexts do
		for _, action in InputSystem.Actions[context.Name] do
			if action.Name == "Shiftlock" then
				continue
			end

			local template = keybindTemplate:Clone()
			template.Title.Text = action.Name
			template.Subtitle.Text = context.Name

			local changedJanitor = Janitor.new()
			local presumedInputBind = action:WaitForChild("Gamepad") :: InputBinding
			local presumedControl = getGamepadType()

			template.PlayerInteractions.Locate.KeyIcon.Image = IconSet[presumedControl][presumedInputBind.KeyCode]
			presumedInputBind:GetPropertyChangedSignal("KeyCode"):Connect(function()
				template.PlayerInteractions.Locate.KeyIcon.Image = IconSet[presumedControl][presumedInputBind.KeyCode]
			end)

			template.PlayerInteractions.Locate.Interact.MouseButton1Click:Connect(function()
				changedJanitor:Cleanup()

				template.PlayerInteractions.Locate.KeyIcon.Visible = false
				template.PlayerInteractions.Locate.Interact.Visible = false
				template.PlayerInteractions.Locate.LoadingEffect.Visible = true

				local thread = task.spawn(function()
					while task.wait() do
						template.PlayerInteractions.Locate.LoadingEffect.Rotation += 5
					end
				end)

				changedJanitor:Add(UserInputService.InputBegan:Connect(function(inputObject, gameProcessedEvent)
					if gameProcessedEvent then
						return
					end

					local keyCode = inputObject.KeyCode
					if not IconSet[presumedControl][keyCode] then
						changedJanitor:Cleanup()
						template.PlayerInteractions.Locate.KeyIcon.Visible = true
						template.PlayerInteractions.Locate.Interact.Visible = true
						template.PlayerInteractions.Locate.LoadingEffect.Visible = false
						task.cancel(thread)
						return
					end

					changedJanitor:Cleanup()
					task.cancel(thread)
					local success = ClientNetwork.PlayerDataFunction:ChangeGamepad(context.Name, action.Name, keyCode.Name)
					if success then
						presumedInputBind.KeyCode = keyCode
						template.PlayerInteractions.Locate.KeyIcon.Image = IconSet[presumedControl][keyCode]
					end

					template.PlayerInteractions.Locate.KeyIcon.Visible = true
					template.PlayerInteractions.Locate.Interact.Visible = true
					template.PlayerInteractions.Locate.LoadingEffect.Visible = false
				end))
			end)

			template.Parent = list
			table.insert(gamepadItems, template)
		end
	end

	return keybindItems, gamepadItems
end

keybindItems, gamepadItems = buildKeybindLists()

localPlayer:GetAttributeChangedSignal("Mobile"):Connect(function()
	adaptDesign()
	updateDeviceVisibility(keybindItems, gamepadItems)
end)
localPlayer:GetAttributeChangedSignal("Gamepad"):Connect(function()
	updateDeviceVisibility(keybindItems, gamepadItems)
end)

adaptDesign()
updateDeviceVisibility(keybindItems, gamepadItems)

abhMenu:GetPropertyChangedSignal("Enabled"):Connect(toggleGameUI)
toggleGameUI()

closeSettings.MouseButton1Click:Connect(function()
	blur.Size = 4
	if referenceUI then
		referenceUI:Destroy()
		referenceUI = nil
	end
	editingFrame.Visible = false
	promptText.Visible = false
	playerlist.Visible = true
	closeMobileEditMenu(keybindItems, gamepadItems)
	mobileUI.Enabled = localPlayer:GetAttribute("Mobile")
	abhMenu.Enabled = false
end)

toggleStadium.MouseButton1Click:Connect(function()
	if not stadiumRemoved then
		local stadium = workspace:FindFirstChild("Stadium")
		if stadium then
			stadium.Parent = ReplicatedStorage
		end
	else
		local stadium = ReplicatedStorage:FindFirstChild("Stadium")
		if stadium then
			stadium.Parent = workspace
		end
	end

	stadiumRemoved = not stadiumRemoved
end)

toggleMobileEdit.MouseButton1Click:Connect(function()
	openMobileEditMenu(keybindItems, gamepadItems)
end)

resetControls.MouseButton1Click:Connect(function()
	if cooldown then
		return
	end
	cooldown = true
	local success, data = ClientNetwork.PlayerDataFunction:ResetControls()
	if success and data then
		local keybinds = localPlayer:FindFirstChild("InputSystem")
		if not keybinds then
			cooldown = false
			return
		end

		local presumedSize = InputSystem:GetPresumedButtonSize()
		for context, actionList in data do
			local inputContext = keybinds:FindFirstChild(context)
			if inputContext then
				for actionName, actionKeybinds in actionList do
					local inputAction = inputContext:FindFirstChild(actionName)
					if inputAction then
						if inputAction:FindFirstChild("Keyboard") then
							inputAction["Keyboard"].KeyCode = Enum.KeyCode[actionKeybinds.Keyboard]
						end
						if inputAction:FindFirstChild("Gamepad") then
							inputAction["Gamepad"].KeyCode = Enum.KeyCode[actionKeybinds.Controller]
						end
						if inputAction:FindFirstChild("Mobile") then
							local presumedUI = inputAction["Mobile"].UIButton.Parent :: Frame
							if presumedUI then
								presumedUI.Size = UDim2.fromOffset(presumedSize, presumedSize)
								presumedUI.Position = UDim2.new(presumedUI.Position.X.Scale, 0, presumedUI.Position.Y.Scale, 0)
							end
						end
					end
				end
			end
		end
	end
	task.wait(0.5)
	cooldown = false
end)