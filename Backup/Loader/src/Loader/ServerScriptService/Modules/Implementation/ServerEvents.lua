local Signal = require("../../../ReplicatedStorage/Utilities/Signal")
local ServerEvents = {}

ServerEvents.League = Signal.new() :: Signal.Signal<(string, ...unknown)>

return ServerEvents