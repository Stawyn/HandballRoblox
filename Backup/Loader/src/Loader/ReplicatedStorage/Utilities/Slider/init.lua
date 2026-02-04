--[[
    Slider Class V2.0.82
    Developed by msix29
    June 2nd, 2025
    
    Check the main post for more info.
    https://devforum.roblox.com/t/v2081-slider-class-create-sliders-with-ease/2190826
]]

local userInputService = game:GetService("UserInputService")
local players = game:GetService("Players")
local guiService = game:GetService("GuiService")
local runService = game:GetService("RunService")

local player = players.LocalPlayer
local mouse = player and player:GetMouse()

local currentCamera = workspace.CurrentCamera

local types = require(script.types)
local utilityFunctions = require(script.utilityFunctions)
local Signal = require(script.Signal)
local Waypoint = require(script.Waypoint)
local Tracker = require(script.Tracker)

local module = {}
module.__index = module

local DEFAULT_PROPERTIES: types.properties = {
	step = 0.01,
	xboxStep = 0.1,
	canLeaveFrame = true,
	canFullyLeaveFrame = false,
	moveToMouse = false,
	waypoints = {},
	trackers = {},
	values = {
		min = 0,
		max = 1
	},
	axis = "X",
}

local function isValidType(item: any, _type: string, warnMessage: string): boolean
	local valid = item and typeof(item):lower() == _type:lower() or false

	if not valid then warn(warnMessage) end

	return valid
end

local function isValidInstance(item: Instance?, className: string, warnMessage: string): boolean?
	local valid = item and item:IsA(className)

	if not valid then warn(warnMessage) end

	return valid
end

function module.new(slider: GuiObject, properties: types.properties): types.Slider
	if not isValidType(slider, "Instance", `"slider" GuiObject must be passed to "slider.new()".`) then return end
	if not isValidType(slider.Parent, "Instance", `"slider.Parent" must be an instance.`) then return end
	if not isValidInstance(slider.Parent, "GuiObject", `"slider.Parent" must be a GuiObject.`) then return end

	properties = properties and typeof(properties) == "table" and properties or DEFAULT_PROPERTIES

	properties.waypoints = properties.waypoints and typeof(properties.waypoints) == "table" and properties.waypoints or DEFAULT_PROPERTIES.waypoints
	properties.trackers = properties.trackers and typeof(properties.trackers) == "table" and properties.trackers or DEFAULT_PROPERTIES.trackers

	for i, v in pairs(DEFAULT_PROPERTIES) do
		if properties[i] ~= nil then continue end

		properties[i] = v
	end

	if properties.values.min >= properties.values.max then
		warn(`"propertes.values.min" is larger than or equal to "properties.values.max", the values will be changed.`)
	end

	properties.values.min = math.clamp(properties.values.min, -math.huge, properties.values.max)
	properties.values.max = math.clamp(properties.values.max, properties.values.min, math.huge)

	properties.defaultValue = properties.defaultValue and typeof(properties.defaultValue) == "number" and properties.defaultValue or (properties.values.max + properties.values.min) / 2
	properties.defaultValue = math.clamp(properties.defaultValue, properties.values.min, properties.values.max)

	local self = setmetatable({
		slider = slider,
		properties = properties,
		lastPosition = slider.Position,
		moved = Signal.new("moved"),
		waypointEntered = Signal.new("waypointEntered"),
		waypointLeaved = Signal.new("waypointLeaved"),
		connections = {},
		
		roundPercentage = properties.step / (properties.values.max - properties.values.min),
		
		currentWaypoint = nil
    }, module)
    
    local value = (properties.defaultValue - properties.values.min)
        / (properties.values.max - properties.values.min)

	self:SetPosition(UDim2.fromScale(
		properties.axis == "X" and value or 0.5,
		properties.axis == "Y" and value or 0.5
	), false)

	return self
end

function module:Enable(widget: PluginGui?): nil
	if not self.slider then return end
	if not self.slider.Parent then return end
	if not mouse then return end

	local function getMousePosition(): (number, number)
        local position = widget and widget:GetRelativeMousePosition() or Vector2.new(mouse.X, mouse.Y)

		return position.X, position.Y
	end

    local function move()
		if not self.slider then return end
		if not self.slider.Parent then return end
		if not mouse then return end
		if not self.isMouseDown then return end

		local mouseX, mouseY = getMousePosition()

		local x = self.properties.axis == "X" and (mouseX - self.slider.Parent.AbsolutePosition.X) / self.slider.Parent.AbsoluteSize.X or 0.5
		local y = self.properties.axis == "Y" and (mouseY - self.slider.Parent.AbsolutePosition.Y) / self.slider.Parent.AbsoluteSize.Y or 0.5
		
		self:SetPosition(UDim2.fromScale(x, y), false)
	end

	local function isMouseInside(canGoToMouseOnX: boolean, canGoToMouseOnY: boolean): boolean
		local x, y = getMousePosition()
		local _x, _y = self.slider.AbsolutePosition.X, self.slider.AbsolutePosition.Y
		local sizeX, sizeY = self.slider.AbsoluteSize.X, self.slider.AbsoluteSize.Y

		local isClickingAwayFromSliderOnX = x - _x > sizeX or x < _x
		local isClickingAwayFromSliderOnY = y - _y > sizeY or y < _y

		local isClickingAwayFromParentOnX = x - self.slider.Parent.AbsolutePosition.X > self.slider.Parent.AbsoluteSize.X or x < self.slider.Parent.AbsolutePosition.X
		local isClickingAwayFromParentOnY = y - self.slider.Parent.AbsolutePosition.Y > self.slider.Parent.AbsoluteSize.Y or y < self.slider.Parent.AbsolutePosition.Y

		if isClickingAwayFromParentOnX and isClickingAwayFromSliderOnX then return end
        if isClickingAwayFromParentOnY and isClickingAwayFromSliderOnY then return end
		if isClickingAwayFromSliderOnX and not canGoToMouseOnX then return end
		if isClickingAwayFromSliderOnY and not canGoToMouseOnY then return end

		return true
	end
    
    local function inputBegan(input: InputObject, gameProcessed: boolean)
        if not self.slider then return end
        if not self.slider.Parent then return end
        if not mouse then return end

        if utilityFunctions.getPlatform() == "console" or userInputService.GamepadEnabled then
            if not (gameProcessed and input.KeyCode == Enum.KeyCode.ButtonA) then return end
            if guiService.SelectedObject ~= self.slider then return end

            guiService:AddSelectionParent("SelectedSlider", guiService.SelectedObject)

            self.selectedSlider = guiService.SelectedObject

            return
        end

        if
            input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch
        then
            return
        end

        local canGoToMouseOnX = self.properties.axis == "X" and self.properties.moveToMouse
        local canGoToMouseOnY = self.properties.axis == "Y" and self.properties.moveToMouse

        if not isMouseInside(canGoToMouseOnX, canGoToMouseOnY) then return end

        self.isMouseDown = true

        move()
    end
    
    local function inputEnded(input: InputObject, _: boolean)
        if not self.slider then return end
        if not self.slider.Parent then return end
        if not mouse then return end

        if
            input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch
        then
            return
        end

        self.isMouseDown = false
    end
    
    -- In plugin widgets, `UserInputService` doesn't fire, so we listen to
    -- input events from both the slider and the parent
    if widget then
        table.insert(self.connections, self.slider.InputBegan:Connect(inputBegan))
        table.insert(self.connections, self.slider.InputEnded:Connect(inputEnded))

        table.insert(self.connections, self.slider.Parent.InputBegan:Connect(inputBegan))
        table.insert(self.connections, self.slider.Parent.InputEnded:Connect(inputEnded))
    else
        table.insert(self.connections, userInputService.InputBegan:Connect(inputBegan))
        table.insert(self.connections, userInputService.InputEnded:Connect(inputEnded))

        table.insert(self.connections, mouse.Move:Connect(move))
    end
    
    -- `Heartbeat` runs better in plugins (for mouse movement)
    -- and `PreRender` would be better for controller imo (is it, though?)
    local callback = if widget then "Heartbeat" else "PreRender"
    
    local x, y = getMousePosition()
	table.insert(self.connections, runService[callback]:Connect(function()
		if not self.slider then return end
		if not self.slider.Parent then return end
        if not mouse then return end
        
        -- Since `mouse.Move` doesn't fire in plugin widgets, we use this.
        if widget and self.isMouseDown then
            local newX, newY = getMousePosition()
            
            if newX ~= x or newY ~= y then
                move()
                x, y = newX, newY
            end
        end

		local input = userInputService:GetGamepadState(Enum.UserInputType.Gamepad1)[17]

		if input.Position.X >= .4 and self.selectedSlider == self.slider then
			self:SetValue(self:GetValue(true) + self.properties.xboxStep + 0.01, true)

		elseif input.Position.X <= -.4 and self.selectedSlider == self.slider then
			self:SetValue(self:GetValue(true) - self.properties.xboxStep, true)
		end

		if input.Position.Y >= .5 or input.Position.Y <= -.5 then
			guiService:RemoveSelectionGroup("SelectedSlider")

			self.selectedSlider = nil
		end
	end))
end

function module:Disable(): ()
	if not self.slider then return end
	if not self.slider.Parent then return end
	if not mouse then return end

	for i, v in pairs(self.connections) do
		v:Disconnect()
	end
end

function module:Reset(): ()
	if not self.slider then return end
	if not self.slider.Parent then return end
	if not mouse then return end

	self:SetValue(self.properties.defaultValue)
end

function module:SetPluginMouse(plugin: Plugin): ()
	mouse = plugin:GetMouse()
end

function module:SetStep(n: number): ()
	if not self.slider then return end
	if not self.slider.Parent then return end
	if not mouse then return end

	self.properties.step = n and typeof(n) == "number" and n < 1 and n > 0 and n or self.properties.step
end

function module:GetStep(): number
	if not self.slider then return end
	if not self.slider.Parent then return end
	if not mouse then return end

	return self.properties.step
end

function module:SetPosition(position: UDim2, forced: boolean, frame: GuiObject?): nil
	if not self.slider then return end
	if not self.slider.Parent then return end
	if not mouse then return end

	frame = frame or self.slider
	
	position = UDim2.fromScale(
		utilityFunctions.round(position.X.Scale, self.roundPercentage),
		utilityFunctions.round(position.Y.Scale, self.roundPercentage)
	)

	local anchorPoint = frame.AnchorPoint
	local _position = frame.Position
	local min, max = utilityFunctions.getMinimumAndMaximumPosition(frame, self.properties, self.properties.axis)

	position = UDim2.fromScale(
		math.clamp(position.X.Scale, min, max),
		math.clamp(position.Y.Scale, min, max)
	)

	frame.Position = position
	frame.AnchorPoint = Vector2.new(.5, .5)

	if frame == self.slider and self.tween then self.tween:Cancel() end

	self.tween = utilityFunctions.getPositionTween(_position, frame, frame.Parent, anchorPoint)
	self.tween:Play()

	if frame == self.slider and position ~= self.lastPosition then
		self.tween.Completed:Wait()

		local waypoint = self.properties.waypoints[utilityFunctions.roundToDecimalPlaces((position[self.properties.axis] or position.X).Scale, 1) * (1 / self.properties.step)]

		if waypoint and waypoint ~= self.currentWaypoint then
			waypoint.entered:Fire()
		end
		
		if self.currentWaypoint then
			self.currentWaypoint.leaved:Fire()
			
			self.currentWaypoint = nil
		end
		
		self.lastPosition = position
		self.moved:Fire(forced)
	end
end

function module:GetValue(usePercentage: boolean?): number
	if not self.slider then return end
	if not self.slider.Parent then return end
	if not mouse then return end
	
    local percentage = utilityFunctions.getPercentageFromPosition(self.slider, self.lastPosition, self.properties, self.properties.axis)
    percentage = utilityFunctions.round(percentage, self.roundPercentage)

	local value = self.properties.values.min + (percentage * (self.properties.values.max - self.properties.values.min))
	value = math.clamp(value, self.properties.values.min, self.properties.values.max)

	return (usePercentage and percentage or value)
end

function module:SetValue(value: number, isPercentage: boolean?): ()	
	if not value then return warn("`value` parameter must be passed to `slider:SetValue()`") end

	local percentage = isPercentage and value or math.abs(value - self.properties.values.min) / math.abs(self.properties.values.max - self.properties.values.min)

	self:SetPosition(UDim2.fromScale(self.properties.axis == "X" and percentage or .5, self.properties.axis == "Y" and percentage or .5), true)
end

function module:SetValues(values: types.values): ()
	if not self.slider then return end
	if not self.slider.Parent then return end
	if not mouse then return end

	self.properties.values = values

	self.moved:Fire(false)
end

function module:GetValues(): types.values
	if not self.slider then return end
	if not self.slider.Parent then return end
	if not mouse then return end

	return self.properties.values
end

function module:AddWaypoint(n: number, isPercentage: boolean?): types.Waypoint
	if not self.slider then return end
	if not self.slider.Parent then return end
	if not mouse then return end

	local position
	local waypointNumber
	local waypointNumberRelevantToSlider
	local frame = self.slider:Clone()

	if isPercentage then 
		position = UDim2.fromScale(
			self.properties.axis == "X" and n or 0.5,
			self.properties.axis == "Y" and n or 0.5
		)

		waypointNumber = n * (1 / self.properties.step) + 1

		local waypointNumber = math.clamp(waypointNumber or 1, 1, (self.properties.values.max - self.properties.values.min) / self.properties.step)
		waypointNumber -= 1
		local _n = 1 / self.properties.step

		waypointNumberRelevantToSlider = waypointNumber
	else
		n = math.clamp(n or 1, 1, (self.properties.values.max - self.properties.values.min) / self.properties.step)
		n -= 1
		local _n = 1 / self.properties.step

		position = UDim2.fromScale(
			self.properties.axis == "X" and n / _n or 0.5,
			self.properties.axis == "Y" and n / _n or 0.5
		)

		waypointNumber = n
		waypointNumberRelevantToSlider = n
	end

	local waypoint =  Waypoint.new(position, frame, self.slider.Parent, waypointNumberRelevantToSlider + 1, waypointNumber)

	self:SetPosition(position, false, frame)
	self.properties.waypoints[waypointNumber] = waypoint

	waypoint.entered:Connect(function()
		self.waypointEntered:Fire(waypoint)
	end)
	
	waypoint.leaved:Connect(function()
		self.waypointLeaved:Fire(waypoint)
	end)

	return waypoint
end

function module:RemoveWaypoint(n: number): ()
	if not self.slider then return end
	if not self.slider.Parent then return end
	if not mouse then return end

	n = math.clamp(n or 1, 1, self.properties.values.max / self.properties.step)

	self.properties.waypoints[n]:Remove()
	self.properties.waypoints[n] = nil
end

function module:ShowWaypoint(n: number): ()
	if not self.slider then return end
	if not self.slider.Parent then return end
	if not mouse then return end

	pcall(function()
		self.properties.waypoints[n]:Show()
	end)
end

function module:HideWaypoint(n: number): ()
	if not self.slider then return end
	if not self.slider.Parent then return end
	if not mouse then return end

	pcall(function()
		self.properties.waypoints[n]:Hide()
	end)
end

function module:ShowWaypoints(): ()	
	if not self.slider then return end
	if not self.slider.Parent then return end
	if not mouse then return end

	for i, v in pairs(self.properties.waypoints) do
		v:Show()
	end
end

function module:HideWaypoints(): ()
	if not self.slider then return end
	if not self.slider.Parent then return end
	if not mouse then return end

	if self.properties.waypoints[0] then
		self.properties.waypoints[0]:Hide()
	end

	for i, v in pairs(self.properties.waypoints) do
		v:Hide()
	end
end

function module:AddTracker(label: TextLabel, roundFunction: types.roundFunction?, textMakerFunction: types.textMakerFunction?): types.Tracker
	if not self.slider then return end
	if not self.slider.Parent then return end
	if not mouse then return end

	local tracker = Tracker.new(self, label, roundFunction, textMakerFunction)
	self:EnableTracker(tracker)

	table.insert(self.properties.trackers, tracker)

	return tracker
end

function module:RemoveTracker(tracker: types.Tracker): ()
	if not self.slider then return end
	if not self.slider.Parent then return end
	if not mouse then return end

	tracker:Disable()

	table.remove(self.properties.trackers, table.find(self.properties.trackers, tracker))
end

function module:EnableTracker(tracker: types.Tracker): ()
	if not self.slider then return end
	if not self.slider.Parent then return end
	if not mouse then return end

	pcall(function()
		tracker:Enable()
	end)
end

function module:DisableTracker(tracker: types.Tracker): ()
	if not self.slider then return end
	if not self.slider.Parent then return end
	if not mouse then return end

	pcall(function()
		tracker:Disable()
	end)
end

function module:EnableTrackers(): ()	
	if not self.slider then return end
	if not self.slider.Parent then return end
	if not mouse then return end

	for i, v in pairs(self.properties.trackers) do
		v:Enable()
	end
end

function module:DisableTrackers(): ()
	if not self.slider then return end
	if not self.slider.Parent then return end
	if not mouse then return end

	for i, v in pairs(self.properties.trackers) do
		v:Disable()
	end
end

return module