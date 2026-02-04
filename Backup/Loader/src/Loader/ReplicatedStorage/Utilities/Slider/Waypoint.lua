local Waypoint = {}
Waypoint.__index = Waypoint

local Signal = require(script.Parent.Signal)
local types = require(script.Parent.types)

function Waypoint.new(position: UDim2, frame: Frame, parent: GuiObject, numberRelevantToSlider: number, n: number): types.Waypoint
	frame.Position = position
	frame.ZIndex = 1
	frame.Visible = false
	frame.BackgroundColor3 = Color3.fromRGB(106, 106, 106)
	frame.Parent = parent
	
	return setmetatable({
		frame = frame,
		position = position,
		parent = parent,
		number = n,
		numberRelevantToSlider = numberRelevantToSlider or n,
		entered = Signal.new(),
		leaved = Signal.new(),
	}, Waypoint)
end

function Waypoint:SetPosition(position: UDim2): nil
	position = position or self.position
	
	self.frame.Position = position
	self.position = position 
end

function Waypoint:Show(): nil
	self.frame.Visible = true
end

function Waypoint:Hide(): nil
	self.frame.Visible = false
end

function Waypoint:SetGuiObject(frame: GuiObject): nil
	if not frame or not frame:IsA("GuiObject") then return end
	
	self.frame:Destroy()
	self.frame = frame
end

function Waypoint:Remove(): nil
	self.frame:Destroy()
	self.parent = nil
	self.position = nil
end

return Waypoint
