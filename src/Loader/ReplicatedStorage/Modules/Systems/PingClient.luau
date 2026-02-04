local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NETWORK_FOLDER = ReplicatedStorage:WaitForChild("Network") :: Folder
local PING_FUNCTION = NETWORK_FOLDER:WaitForChild("Ping") :: RemoteFunction

function PING_FUNCTION.OnClientInvoke()
	return true
end

return {}
