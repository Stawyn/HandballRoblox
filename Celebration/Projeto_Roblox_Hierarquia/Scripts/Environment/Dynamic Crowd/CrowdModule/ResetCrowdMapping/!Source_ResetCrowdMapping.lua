local CrowdAssets = require(script.Parent.CrowdAssets)

return function()
	for index: number, stand: BasePart in pairs(workspace:GetDescendants()) do
		if not stand:IsA("BasePart") then continue end
		if not stand.Name:find("Seat") then continue end
		if not stand:FindFirstChild("SeatChange") then continue end

		for i, v in pairs(stand:GetChildren()) do
			if v.Name ~= "Crowd" then continue end
			local CrowdAssetsTable = CrowdAssets[9]
			v.Texture = CrowdAssetsTable[math.random(1, #CrowdAssetsTable)]
		end
	end
end
