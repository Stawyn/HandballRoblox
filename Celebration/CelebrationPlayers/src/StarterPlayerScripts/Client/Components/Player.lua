local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local CountryModule = require(ReplicatedStorage.Packages.Country)


local New = Fusion.New
local Tween = Fusion.Tween
local Children = Fusion.Children
local Computed = Fusion.Computed
local Value = Fusion.Value
local OnEvent = Fusion.OnEvent

return function(props)
	local forceDisabled = Value(false)
	local currentPing = Value(props.Ping.Value)
		
    -- im so sorry for this horrible code solution
    task.delay(0.1, function()
        forceDisabled:set(false)
	end)
	
	props.Ping:GetPropertyChangedSignal("Value"):Connect(function()
		currentPing:set(props.Ping.Value)
	end)

    return New "Frame" {
        BackgroundTransparency = 1,
        LayoutOrder = props.Order:get(),
        Size = Tween(Computed(function()
            if forceDisabled:get() or not props.Visible:get() then
                return UDim2.fromScale(1, 0)
            else
                return UDim2.new(1, 0, 0, 30)
            end
        end), TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, 0.3)),
        ClipsDescendants = true,

        [Children] = {
            New "Frame" {
                BackgroundTransparency = 1,
                Position = Tween(Computed(function()
                    if forceDisabled:get() or not props.Visible:get() then
                        return UDim2.fromScale(1, 0)
                    else
                        return UDim2.fromScale(0, 0)
                    end
                end), TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false)),
                Size = UDim2.fromScale(1, 1),

                [Children] = {
                    New "Frame" {
                        BackgroundTransparency = 0.5,
                        BackgroundColor3 = Color3.fromHex("#000000"),
                        Size = UDim2.fromScale(1, 1),
                    },

                    New "ImageLabel" {
                        Size = UDim2.fromOffset(45, 30),
                        Position = UDim2.fromOffset(0, 0),
                        BackgroundTransparency = 1,
                        Image = ("rbxthumb://type=AvatarHeadShot&id=%s&w=60&h=60"):format(props.UserId),
                        ImageTransparency = 0,
                        ScaleType = Enum.ScaleType.Crop,
                        ZIndex = 2,

                        [Children] = {
                            New "UIGradient" {
                                Transparency = NumberSequence.new({
                                    NumberSequenceKeypoint.new(0, 0),
                                    NumberSequenceKeypoint.new(1, .75)
                                }),
                            }
                        }
					},
					
					New "ImageLabel" {
						Size = UDim2.fromOffset(45, 60),
						Position = UDim2.new(1, -45, 0, 0),
						BackgroundTransparency = 1,
						Image = "http://www.roblox.com/asset/?id=14367680112",
						ImageTransparency = props.Staff and 0 or 1,
						ScaleType = Enum.ScaleType.Crop,
						ZIndex = 2,

						[Children] = {
							New "UIGradient" {
								Transparency = NumberSequence.new({
									NumberSequenceKeypoint.new(0, 1),
									NumberSequenceKeypoint.new(1, 0)
								}),
							}
						}
					},
					
					New "ImageLabel" {
						Size = UDim2.fromOffset(120, 30),
						Position = UDim2.fromOffset(0, 0),
						BackgroundTransparency = 0.75,
						Image = CountryModule.getCountry(props.Country)["decal"] or "",
						ImageTransparency = 0.6,
						ScaleType = Enum.ScaleType.Crop,
						ZIndex = 0,

						[Children] = {
							New "UIGradient" {
								Transparency = NumberSequence.new({
									NumberSequenceKeypoint.new(0, 0),
									NumberSequenceKeypoint.new(1, 1)
								}),
							}
						}
					},

                    New "TextLabel" {
                        Font = Enum.Font.GothamBold,
						Text = props.Name.."\n"..props.Team,
						TextColor3 = props.Suspended and Color3.fromRGB(255, 0, 0) or Color3.fromHex("#FFFFFF"),
                        TextSize = 10,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        BackgroundTransparency = 1,
                        Position = UDim2.fromOffset(45, 0),
                        Size = UDim2.fromScale(0, 1),
                        ZIndex = 3,
                    },

                    New "Frame" {
                        AnchorPoint = Vector2.new(1, 1),
                        BackgroundColor3 = Color3.fromHex("#FFFFFF"),
                        BackgroundTransparency = 0.9,
                        BorderSizePixel = 0,
                        Position = UDim2.fromScale(1, 1),
                        Size = UDim2.new(1, -16, 0, 1),
                        Visible = Computed(function()
                            return not props.AtBottom:get()
                        end),
                        ZIndex = 3,
                    },
					
					New "TextLabel" {
						Font = Enum.Font.GothamBold,
						TextSize = 12,
                        BackgroundTransparency = 1,
						TextColor3 = Color3.fromHex("#FFFFFF"),
						Text = Computed(function()
							return tostring(currentPing:get()).."ms"
						end),
                        AnchorPoint = Vector2.new(1, 0.5),
                        Size = UDim2.fromOffset(16, 16),
                        Position = UDim2.new(1, -16, 0.5, 0),
                        ZIndex = 3,
                    }
                },
            },
        }
    }
end
