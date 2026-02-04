type SpawnState = {
	state: boolean
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BallService = require(ServerScriptService:WaitForChild("Services"):WaitForChild("BallService"))
local ballEvent: RemoteEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BallEvent")

ballEvent.OnServerEvent:Connect(function(player: Player, event: string, ...)
	if event == "Spawn" then
		if not player.Backpack:FindFirstChild("SpawnTool") and not player.Character:FindFirstChild("SpawnTool") then return end
		local properties = ...
		if properties.state == true then 
			BallService.new(player)
		else
			BallService:Clear()
		end	
	elseif event == "Shoot" then
		local properties = ...
		if player.Character and player.Character.HumanoidRootPart:FindFirstChild("BallWeld") then
			local ballInstance: MeshPart = player.Character.HumanoidRootPart.BallWeld.Part0
			BallService:Kick(player, ballInstance, properties)
		end
	end
end)
