local Tracker = {}
Tracker.__index = Tracker

local types = require(script.Parent.types)
local utilityFunctions = require(script.Parent.utilityFunctions)

local function DEFAULT_ROUND_FUNCTION(n: number): string
	return tostring(utilityFunctions.roundToDecimalPlaces(n, 2))
end

local function DEFAULT_TEXT_MAKER_FUNCTION(_string: string): string
	return _string
end

function Tracker.new(slider: types.Slider, label: TextLabel, roundFunction: types.roundFunction?, textMakerFunction: types.textMakerFunction?): types.Tracker
	return setmetatable({
		slider = slider,
		label = label,
		roundFunction = roundFunction or DEFAULT_ROUND_FUNCTION,
		textMakerFunction = textMakerFunction or DEFAULT_TEXT_MAKER_FUNCTION,
		connections = {}
	}, Tracker)
end

function Tracker:Enable(): nil	
	local function changeText()
		local value = self.slider:GetValue()
		local roundedValue = self.roundFunction(value)
		local text = self.textMakerFunction(roundedValue)
		
		self.label.Text = `{text}`
	end
	
	changeText()
	
	table.insert(self.connections, self.slider.moved:Connect(changeText))
end

function Tracker:Disable(): nil
	for i, v in pairs(self.connections) do
		v:Disconnect()
	end
end

function Tracker:SetSlider(slider: types.Slider): nil
	self:Disable()

	self.slider = slider

	self:Enable()
end

function Tracker:SetLabel(label: TextLabel): nil
	self:Disable()

	self.label = label

	self:Enable()
end

return Tracker

