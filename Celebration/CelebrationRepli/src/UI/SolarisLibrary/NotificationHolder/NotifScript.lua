local MainFrame = script.Parent
local Notif = MainFrame.NotificationBody
local TweenService = game:GetService('TweenService')

MainFrame.ChildAdded:Connect(function(a)
	if a.Name == "NotificationBody" then
		TweenService:Create(a.NotificationFrame,TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),{Position = UDim2.new(0,0,0, 0)}):Play()
	end
end)


local Notify = {}

function Notify:New(title,text)
	local NotifClone = Notif:Clone()
	NotifClone.Parent = MainFrame
	NotifClone.Visible = true
	NotifClone.NotificationFrame.NotificationTopFrame.NotificationTitle.Text = title
	NotifClone.NotificationFrame.NotificationTextFrame.NotificationText.Text = text

	NotifClone.NotificationFrame.NotificationTopFrame.NotificationCloseBtn.MouseButton1Click:Connect(function()
		TweenService:Create(NotifClone.NotificationFrame,TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),{Position = UDim2.new(1,15,0, 0)}):Play()
		delay(0.3,function()
			NotifClone:Destroy()
		end)
	end)
end

return Notify