local types = require(script.Parent.types)

local Signal = {}
Signal.__index = Signal

function Signal.new(name): types.Signal
	local event = Instance.new("BindableEvent")
	event.Name = name or event.Name
	
	return setmetatable({
		event = event,
		connections = {}
	}, Signal)
end

function Signal:Fire(...: any): nil
	self.event:Fire(...)
end

function Signal:Connect(callback: (...any) -> (...any)): nil
	local connection = self.event.Event:Connect(callback)
	
	table.insert(self.connections, connection)
	
	return connection
end

function Signal:Disconnect()	
	for i, v in pairs(self.connections) do
		v:Disconnect()
	end
end

return Signal

