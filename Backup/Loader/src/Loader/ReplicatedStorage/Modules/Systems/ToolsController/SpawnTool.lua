local UserInputService = game:GetService("UserInputService")

local SpawnTool = {}
local ClientNetwork = require("../../Implementation/ClientNetwork")
local Maid = require("../../../Utilities/Maid")
local InputSystem = require("../../Implementation/InputSystem")

function SpawnTool:Initialize(tool: Tool)	
	local toolMaid = Maid.new()
	tool.Equipped:Connect(function()
		InputSystem.Contexts["Spawn Tool"].Enabled = true
		
		toolMaid:GiveTask(InputSystem.Actions["Spawn Tool"].Spawn.Pressed:Connect(function()
			ClientNetwork.BallEvents:SpawnRequest()
		end))
		
		toolMaid:GiveTask(InputSystem.Actions["Spawn Tool"]["Remove balls"].Pressed:Connect(function()
			ClientNetwork.BallEvents:ClearRequest()
		end))
	end)
	
	tool.Unequipped:Connect(function()
		InputSystem.Contexts["Spawn Tool"].Enabled = false
		toolMaid:DoCleaning()
	end)
	
	tool.Destroying:Connect(function()
		toolMaid:DoCleaning()
	end)
end

return SpawnTool