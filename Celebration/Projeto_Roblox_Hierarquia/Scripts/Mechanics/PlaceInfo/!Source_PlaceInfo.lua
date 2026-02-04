local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HTTPService = game:GetService("HttpService")

local FunctionEvents = ReplicatedStorage:WaitForChild("RemoteFunctions")
local PlaceInfoEvent = FunctionEvents.PlaceInfo

local ServerInfo = HTTPService:JSONDecode(HTTPService:GetAsync('http://ip-api.com/json/'))

PlaceInfoEvent.OnServerInvoke = function(Player, Command, Variables)
	
	if Command == "Server" then

		local State = ServerInfo["country"]
		local City = ServerInfo["regionName"]

		local Text = State..(", "..City)

		return Text
	end
end
