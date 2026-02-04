local l__TweenService__1 = game:GetService("TweenService");
local l__RunService__2 = game:GetService("RunService");
local l__Debris__3 = game:GetService("Debris");
local Players = game:GetService("Players")
local v4 = {};
local l__Markers__5 = game:GetService("ReplicatedStorage"):WaitForChild("Markers");
for v6, v7 in pairs(l__Markers__5:GetChildren()) do
	if v7:IsA("Part") or v7:IsA("BasePart") then
		
		local content, isReady = Players:GetUserThumbnailAsync(
			v7.Config.SenderId.Value,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size420x420
		)
		
		local v8 = script.Container:Clone();
		v8.ImageColor3 = v7.Config.MarkerColor.Value;
		v8.RotateLabel.Arrow.ImageColor3 = v7.Config.MarkerColor.Value;
		v8.Icon.Image = content;
		v8.PName.Text = v7.Config.SenderName.Value
		table.insert(v4, { v8, v7 });
		v8.Parent = script.Parent.Holder;
		l__Debris__3:AddItem(v8, 2);
	end;
end;
local l__AbsoluteSize__1 = script.Parent.Holder.AbsoluteSize;
function ClampMarkerToBorder(p1, p2, p3)
	p1 = l__AbsoluteSize__1.X - p1;
	p2 = l__AbsoluteSize__1.Y - p2;
	if math.min(p2, l__AbsoluteSize__1.Y - p2) < math.min(p1, l__AbsoluteSize__1.X - p1) then

	elseif p1 < l__AbsoluteSize__1.X - p1 then
		return 0, math.clamp(p2, 0, l__AbsoluteSize__1.Y - p3.Y);
	else
		return l__AbsoluteSize__1.X - p3.X, math.clamp(p2, 0, l__AbsoluteSize__1.Y - p3.Y);
	end;
	if p2 < l__AbsoluteSize__1.Y - p2 then
		return math.clamp(p1, 0, l__AbsoluteSize__1.X - p3.X), 0;
	end;
	return math.clamp(p1, 0, l__AbsoluteSize__1.X - p3.X), l__AbsoluteSize__1.Y - p3.Y;
end;

l__Markers__5.ChildAdded:Connect(function(p4)
	
	local content, isReady = Players:GetUserThumbnailAsync(
		p4.Config.SenderId.Value,
		Enum.ThumbnailType.HeadShot,
		Enum.ThumbnailSize.Size420x420
	)
	
	local v9 = script.Container:Clone();
	v9.ImageColor3 = p4.Config.MarkerColor.Value;
	v9.RotateLabel.Arrow.ImageColor3 = p4.Config.MarkerColor.Value;
	v9.Icon.Image = content;
	v9.PName.Text = p4.Config.SenderName.Value
	table.insert(v4, { v9, p4 });
	v9.Parent = script.Parent.Holder;
	l__Debris__3:AddItem(v9, 2);
end);
l__Markers__5.ChildRemoved:Connect(function(p5)
	for v10, v11 in pairs(v4) do
		if v11[2] == p5 then
			table.remove(v4, v10);
		end;
	end;
end);
l__RunService__2.Heartbeat:Connect(function()
	for v12, v13 in pairs(v4) do
		local v14 = v13[1];
		local v15 = v13[2];
		v14.Visible = v15.Config.Enabled.Value;
		if v15.Config.Enabled.Value then
			local v16 = nil;
			local v17, v18 = workspace.CurrentCamera:WorldToScreenPoint(v15.Position);
			local v19 = workspace.CurrentCamera.CFrame:Inverse() * v15.CFrame;
			local l__AbsoluteSize__20 = v14.AbsoluteSize;
			local v21 = v17.X - l__AbsoluteSize__20.X / 2;
			local v22 = v17.Y - l__AbsoluteSize__20.Y / 2;
			if v17.Z < 0 then
				local v23, v24 = ClampMarkerToBorder(v21, v22, l__AbsoluteSize__20);
				v21 = v23;
				v22 = v24;
			else
				if v21 < 0 then
					v21 = 0;
				elseif l__AbsoluteSize__1.X - l__AbsoluteSize__20.X < v21 then
					v21 = l__AbsoluteSize__1.X - l__AbsoluteSize__20.X;
				end;
				if v22 < 0 then
					v22 = 0;
				elseif l__AbsoluteSize__1.Y - l__AbsoluteSize__20.Y < v22 then
					v22 = l__AbsoluteSize__1.Y - l__AbsoluteSize__20.Y;
				end;
			end;
			v14.RotateLabel.Visible = not v18;
			v14.RotateLabel.Rotation = 90 + math.deg(math.atan2(v19.Z, v19.X));
			v14.Position = UDim2.new(0, v21, 0, v22);
			l__TweenService__1:Create(v14, TweenInfo.new(0.5), {
				ImageColor3 = v15.Config.MarkerColor.Value
			}):Play();
			l__TweenService__1:Create(v14.RotateLabel.Arrow, TweenInfo.new(0.5), {
				ImageColor3 = v15.Config.MarkerColor.Value
			}):Play();
			v16 = tick();
			if v15.Config.BurstType.Value == "Normal" then
				if math.floor(v16 % 1.5 * 100) / 100 <= 0.01 then
					local v25 = script.BurstRings:Clone();
					v25.ImageColor3 = v15.Config.MarkerColor.Value;
					
					v25.Parent = v14;
					l__TweenService__1:Create(v25, TweenInfo.new(1), {
						Size = UDim2.new(2, 0, 2, 0), 
						ImageTransparency = 1
					}):Play();
					l__Debris__3:AddItem(v25, 1);
				end;
			elseif v15.Config.BurstType.Value == "Burst" then
				if math.floor(v16 % 1.5 * 100) / 100 <= 0.01 then
					local v26 = script.BurstRings:Clone();
					v26.ImageColor3 = Color3.fromRGB(255, 0, 0);
					v26.Parent = v14;
					l__TweenService__1:Create(v26, TweenInfo.new(1), {
						Size = UDim2.new(2, 0, 2, 0), 
						ImageTransparency = 1
					}):Play();
					l__Debris__3:AddItem(v26, 1);
				elseif math.floor(v16 % 0.75 * 100) / 100 <= 0.01 then
					local v27 = script.BurstRings:Clone();
					v27.ImageColor3 = Color3.fromRGB(255, 89, 89);
					v27.Parent = v14;
					l__TweenService__1:Create(v27, TweenInfo.new(1), {
						Size = UDim2.new(2, 0, 2, 0), 
						ImageTransparency = 1
					}):Play();
					l__Debris__3:AddItem(v27, 1);
				end;
			end;
		end;
	end;
end);