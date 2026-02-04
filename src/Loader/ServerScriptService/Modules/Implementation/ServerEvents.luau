local Signal = require(game:GetService("ReplicatedStorage"):WaitForChild("Utilities"):WaitForChild("Signal"))
local ServerEvents = {}

ServerEvents.League = Signal.new() :: Signal.Signal<(string, ...unknown)>

return ServerEvents