--!nocheck
local ServerScriptService = game:GetService("ServerScriptService")

local modules = ServerScriptService:WaitForChild("Modules"):WaitForChild("Systems")

for _, v in modules:GetChildren() do
	if v:IsA("ModuleScript") then
		require(v)
	end
end