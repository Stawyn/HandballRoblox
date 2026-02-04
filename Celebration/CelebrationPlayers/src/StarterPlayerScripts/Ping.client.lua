local pingEvent: RemoteFunction = game:GetService("ReplicatedStorage"):WaitForChild("RemoteFunctions"):WaitForChild("Ping")

pingEvent.OnClientInvoke = function(argument)
	if argument ~= "Ping" then return end
	return true
end