--!strict
--!native

local ControlHints = {}

local UserInputService = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local HINT_TAG = "Hint"

local Sorting = require(script:WaitForChild("Sorting"))
local Settings = require(script:WaitForChild("Settings"))

-- Load selected icon set.
local iconSet = Settings.ICON_SET

local localPlayer = Players.LocalPlayer

-- Load selected display style.
local displayStyle = Settings.DISPLAY_STYLE
local TemplateHintsFrame = displayStyle:FindFirstChild("HintsFrame") :: Frame?
assert(TemplateHintsFrame, "'HintsFrame' Frame not found in '" .. displayStyle.Name .. "' display style.")
local TemplateHint = TemplateHintsFrame:FindFirstChild("HintTemplate") :: Frame?
assert(TemplateHint, "'HintTemplate' Frame not found in 'HintsFrame' Frame.")

-- Helper to find object and its top-level container under a RootContainer GuiObject.
local function getElementAndContainer(RootContainer: GuiObject, elementName: string): (GuiObject, GuiObject?)
	local Element = RootContainer:FindFirstChild(elementName, true) :: GuiObject?
	assert(Element, "'" .. elementName .. "' GuiObject not found in '" .. RootContainer.Name .. "' " .. RootContainer.ClassName .. ".")
	local Container: GuiObject?
	while Container and Container:IsDescendantOf(RootContainer) do
		local NewContainer = Container:FindFirstAncestorOfClass("GuiObject")
		if not NewContainer or NewContainer:IsDescendantOf(RootContainer) then break end
		Container = NewContainer
	end
	return Element, Container
end

-- Does display style have a separator?
local hasSeparator = TemplateHint:FindFirstChild("Separator", true) ~= nil

-- Determines gamepad type: "xbox" or "ps".
local function getGamepadType(): string
	local buttonString = UserInputService:GetStringForKeyCode(Enum.KeyCode.ButtonA)
	if buttonString == "ButtonCross" then
		return "ps"
	else
		return "xbox"  -- Default.
	end
end

-- Calculate scale factor for dynamic scaling, if enabled.
local function getScaleFactor(width: number): number
	local t = math.clamp((width - Settings.MIN_SCREEN_WIDTH) / (Settings.MAX_SCREEN_WIDTH - Settings.MIN_SCREEN_WIDTH), 0, 1)
	return 1 + t * (Settings.MAX_SCALE_FACTOR - 1)
end

-- Returns icon asset ID (rbxassetid://...) for KeyCode; empty string if not found.
-- specificPlatform options: 'keyboard', 'mobile', 'xbox', 'ps', and any others you add
function ControlHints:GetIconId(keyCode: Enum.KeyCode, specificPlatform: string?, isPressed: boolean?): string
	local useActive = isPressed == true and Settings.ENABLE_RESPONSIVE and iconSet.supportsResponsive == true

	local platform: string
	if specificPlatform then
		if specificPlatform == "keyboard" or specificPlatform == "mobile" then
			platform = specificPlatform
		else
			platform = specificPlatform or "xbox"
		end
	else
		if UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then
			platform = getGamepadType()
		elseif UserInputService.PreferredInput == Enum.PreferredInput.Touch then
			platform = "mobile"
		else
			platform = "keyboard"
		end
	end

	local suffix = useActive and "_active" or ""
	local tableName = platform .. suffix
	local iconTable = iconSet[tableName] or iconSet[platform]

	local iconId = iconTable[keyCode] or ""
	if iconId == "" then
		warn("Missing icon asset ID for '" .. keyCode.Name .. "' KeyCode on '" .. platform .. "' platform (using '" .. tableName .. "' table). No icon will be displayed.")
	end
	return iconId
end

-- Returns KeyCodes for bindings matching inputType (e.g., "KeyboardJump").
local function getBindingKeyCodes(Action: InputAction, inputType: string): {Enum.KeyCode}
	local keyCodes = {}
	for _, binding in ipairs(Action:GetChildren()) do
		if binding:IsA("InputBinding") and binding.Name:match("^" .. inputType) then
			if inputType == "Mobile" then
				table.insert(keyCodes, Enum.KeyCode.Touch)
			else
				local key = binding.KeyCode
				if key and key ~= Enum.KeyCode.Unknown then
					table.insert(keyCodes, key)
				end
			end
		end
	end
	if #keyCodes == 0 then
		if Settings.DEBUG then
			warn("Missing InputBindings for '" .. Action.Name .. "' InputAction on '" .. inputType .. "' inputType. This InputAction will not be displayed.")
		end
	end
	return keyCodes
end

-- Creates UI from selected display style template. Optionally set the Parent of the UI.
function ControlHints:CreateUI(optionalParent: Instance?): ScreenGui
	local ScreenGui = displayStyle:Clone()
	if optionalParent then
		ScreenGui.Parent = optionalParent
	end
	
	ScreenGui.Enabled = not localPlayer:GetAttribute("Mobile")

	-- Set hint template visibility to false
	local HintsFrame = ScreenGui.HintsFrame
	local HintTemplate = HintsFrame.HintTemplate
	HintTemplate.Visible = false

	-- Setup dynamic scaling (if enabled) on this ScreenGui instance
	self:ApplyScaling(ScreenGui)

	return ScreenGui
end

-- Applies current scaling to all active hints for dynamic scaling, if enabled.
function ControlHints:ApplyScaling(ScreenGui: ScreenGui)
	local width = ScreenGui.AbsoluteSize.X
	if width <= 0 then 
		warn("ScreenGui's AbsoluteSize.X is " .. width .. " (<= 0). Skipping dynamic scaling.")
		return
	end

	local isGamepad = UserInputService.PreferredInput == Enum.PreferredInput.Gamepad
	local useDynamic = Settings.ENABLE_DYNAMIC_SCALING and isGamepad
	local scale = useDynamic and getScaleFactor(width) or 1

	local target_text = math.floor(Settings.BASE_FONT_SIZE * scale)
	local target_icon = math.floor(Settings.BASE_ICON_SIZE * scale)

	for _, Hint in ipairs(CollectionService:GetTagged(HINT_TAG)) do
		for _, constraint in ipairs(Hint:GetDescendants()) do
			if typeof(constraint) ~= "Instance" then continue end
			if constraint:IsA("UITextSizeConstraint") then
				constraint.MaxTextSize = target_text
				constraint.MinTextSize = target_text
			elseif constraint:IsA("UISizeConstraint") then
				constraint.MaxSize = Vector2.new(target_icon, target_icon)
				constraint.MinSize = Vector2.new(target_icon, target_icon)
			end
		end
	end
end

-- Full update: uses IAS setup to refresh entire Control Hints display
-- Partial update: uses an InputAction to refresh a single hint on the display
function ControlHints:UpdateUI(ScreenGui: ScreenGui, iasSetupOrAction: {[InputContext]: {InputAction}} | InputAction)
	local HintsFrame = ScreenGui:FindFirstChild("HintsFrame") :: Frame?
	assert(HintsFrame, "'HintsFrame' Frame not found in provided ScreenGui.")

	local inputType
	if UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then 
		inputType = "Gamepad"
	elseif UserInputService.PreferredInput == Enum.PreferredInput.Touch then
		inputType = "Mobile"
	else
		inputType = "Keyboard"
	end

	-- Partial update for single InputAction
	if typeof(iasSetupOrAction) == "Instance" then
		local Action = iasSetupOrAction
		local Context = Action:FindFirstAncestorOfClass("InputContext")
		local active = (Action.Enabled and (Context and Context.Enabled)) :: boolean

		local isPressed = Settings.ENABLE_RESPONSIVE and Action.Type == Enum.InputActionType.Bool and Action:GetState() == true or false

		local actionName = Action:GetAttribute("CustomName") :: string? or Action.Name

		local found = false
		for _, Hint in ipairs(CollectionService:GetTagged(HINT_TAG)) do
			local Label = Hint:FindFirstChild("Label", true) :: TextLabel?
			if Label and Label.Text == actionName then
				found = true
				if not active then Hint:Destroy() break end
				if not Action:FindFirstChildOfClass("InputBinding") then Hint:Destroy() break end

				-- Collect all primary icon images
				local icons = {}
				for _, desc in ipairs(Hint:GetDescendants()) do
					if typeof(desc) ~= "Instance" then continue end
					if desc:IsA("ImageLabel") and desc.Name == "Icon" then
						table.insert(icons, desc)
					end
				end

				-- Sort by root container LayoutOrder (then by own LO if needed)
				table.sort(icons, function(a, b)
					local rootA: GuiObject = a
					while rootA.Parent and rootA.Parent ~= Hint and rootA.Parent:IsA("GuiObject") do rootA = rootA.Parent end
					local rootB: GuiObject = b
					while rootB.Parent and rootB.Parent ~= Hint and rootB.Parent:IsA("GuiObject") do rootB = rootB.Parent end

					if rootA.LayoutOrder == rootB.LayoutOrder then
						return a.LayoutOrder < b.LayoutOrder
					end
					return rootA.LayoutOrder < rootB.LayoutOrder
				end)
				
				local keyCodes = getBindingKeyCodes(Action, inputType)
				
				for i = 1, math.min(#icons, #keyCodes) do
					icons[i].Image = ControlHints:GetIconId(keyCodes[i], nil, isPressed)
				end

				break
			end
		end
		if not found then
			if Settings.DEBUG and active then
				warn("No hint found for '" .. actionName .. "' InputAction during partial update. This InputAction will not be displayed.")
			end
		end
		return
	end

	-- Full update/refresh
	local HintTemplate = HintsFrame:FindFirstChild("HintTemplate") :: Frame?
	assert(HintTemplate, "'HintTemplate' Frame not found in 'HintsFrame' Frame.")

	-- Clear existing hints
	for _, PrevHint in ipairs(CollectionService:GetTagged(HINT_TAG)) do
		PrevHint:Destroy()
	end

	local hints = {}

	for Context, actionList in pairs(iasSetupOrAction) do
		if not Context.Enabled then continue end
		for _, Action in ipairs(actionList) do
			if not Action.Enabled then continue end
			if not Action:FindFirstChildOfClass("InputBinding") then continue end
			local keyCodes = getBindingKeyCodes(Action, inputType)
			if #keyCodes > 0 then
				local isPressed = Settings.ENABLE_RESPONSIVE and Action.Type == Enum.InputActionType.Bool and Action:GetState() == true or false
				local iconIds = {}
				local allIconsFound = true
				for _, keyCode in ipairs(keyCodes) do
					local iconId = ControlHints:GetIconId(keyCode, nil, isPressed)
					if iconId == "" then
						warn("Missing icon asset ID for '" .. keyCode.Name .. "' KeyCode. '" .. Action.Name .. "' InputAction will not be displayed.")
						allIconsFound = false
						break
					end
					table.insert(iconIds, iconId)
				end
				if allIconsFound then
					local nameToApply = Action:GetAttribute("CustomName") :: string? or Action.Name
					local customOrder = Action:GetAttribute("CustomOrder") :: number?
					local minSortIndex = math.huge
					local sortIndex = (inputType == "Keyboard" and Sorting.keyboard_sort_index) or (inputType == "Gamepad" and Sorting.gamepad_sort_index) or Sorting.mobile_sort_index
					if not sortIndex then
						if Settings.DEBUG then
							warn("No sort table found for '" .. inputType .. "' inputType. Add sort table to the Sorting module for consistent hints display.")
						end
						sortIndex = {}
					end
					for _, keyCode in ipairs(keyCodes) do
						local idx = sortIndex[keyCode] or math.huge
						minSortIndex = math.min(minSortIndex, idx)
					end
					table.insert(hints, {
						keyCodes = keyCodes,
						iconIds = iconIds,
						actionName = nameToApply,
						customOrder = customOrder,
						minSortIndex = minSortIndex
					})
				end
			end
		end
	end

	-- Sort hints
	table.sort(hints, function(a, b)
		local indexA = a.customOrder or a.minSortIndex or math.huge
		local indexB = b.customOrder or b.minSortIndex or math.huge
		return indexA < indexB
	end)

	-- Populate hints
	for _, hint in ipairs(hints) do
		local NewHint = HintTemplate:Clone()
		CollectionService:AddTag(NewHint, HINT_TAG)
		NewHint.Name = hint.actionName
		NewHint.LayoutOrder = hint.customOrder or hint.minSortIndex or 10000

		local Label = NewHint:FindFirstChild("Label", true) :: TextLabel?
		assert(Label, "'Label' TextLabel not found in '" .. hint.actionName .. "' hint.")
		local Icon, IconContainer = getElementAndContainer(NewHint, "Icon")
		assert(Icon:IsA("ImageLabel"), "'Icon' ImageLabel not found in '" .. hint.actionName .. "' hint.")
		local Separator, SeparatorContainer = hasSeparator and getElementAndContainer(NewHint, "Separator") or nil, nil

		Label.Text = hint.actionName

		if #hint.iconIds == 1 then
			Icon.Image = hint.iconIds[1]

			if Separator then Separator:Destroy() end
			if SeparatorContainer then SeparatorContainer:Destroy() end
		else
			-- Build multi-key group
			local currentLO = IconContainer and IconContainer.LayoutOrder or Icon.LayoutOrder
			local isFirst = true

			for _, iconId in ipairs(hint.iconIds) do
				if not isFirst and hasSeparator and Separator then
					if SeparatorContainer then
						local NewSeparatorContainer = SeparatorContainer:Clone()

						NewSeparatorContainer.LayoutOrder = currentLO
						NewSeparatorContainer.Visible = true
						NewSeparatorContainer.Parent = NewHint
					else
						local NewSeparator = Separator:Clone()
						NewSeparator.LayoutOrder = currentLO
						NewSeparator.Visible = true
						NewSeparator.Parent = NewHint
					end
					currentLO += Settings.INCREMENT
				end

				if IconContainer then
					local NewIconContainer = IconContainer:Clone()
					NewIconContainer.Parent = NewHint

					local NewIcon = NewIconContainer:FindFirstChild("Icon", true) :: ImageLabel?
					assert(NewIcon, "'Icon' ImageLabel not found in '" .. hint.actionName .. "' hint.")

					NewIcon.Image = iconId
					NewIcon.LayoutOrder = currentLO
				else
					local NewIcon = Icon:Clone()

					NewIcon.Image = iconId
					NewIcon.LayoutOrder = currentLO
					NewIcon.Parent = NewHint
				end
				currentLO += Settings.INCREMENT
				isFirst = false
			end

			-- Remove original single-key structure
			if Icon then Icon:Destroy() end
			if IconContainer then IconContainer:Destroy() end
			if Separator then Separator:Destroy() end
			if SeparatorContainer then SeparatorContainer:Destroy() end
		end
		NewHint.Visible = true
		NewHint.Parent = HintsFrame
	end

	-- Preload icons for responsive highlighting if enabled
	if Settings.ENABLE_RESPONSIVE then
		local allAssetIds = {}
		for _, hint in ipairs(hints) do
			for _, keyCode in ipairs(hint.keyCodes) do
				local outlineId = ControlHints:GetIconId(keyCode, nil, false)
				local activeId = ControlHints:GetIconId(keyCode, nil, true)
				if outlineId ~= "" then allAssetIds[outlineId] = true end
				if activeId ~= "" then allAssetIds[activeId] = true end
			end
		end

		local preloadList = {}
		for assetId in pairs(allAssetIds) do
			local Icon = Instance.new("ImageLabel")
			Icon.Image = assetId
			table.insert(preloadList, Icon)
		end

		if #preloadList > 0 then
			ContentProvider:PreloadAsync(preloadList)
			table.clear(preloadList)
		end
	end

	-- Apply scaling to newly created hints
	self:ApplyScaling(ScreenGui)
end

return ControlHints