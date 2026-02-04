for _, velocityReduer: BasePart in pairs(workspace.Core.VelocityReducer:GetChildren()) do
	if not velocityReduer:IsA("BasePart") then return end
	velocityReduer.Touched:Connect(function(partThatTouched: BasePart)
		if partThatTouched:IsDescendantOf(workspace.Core.Balls) then
			partThatTouched.AssemblyLinearVelocity = Vector3.new()
		end
	end)
end
