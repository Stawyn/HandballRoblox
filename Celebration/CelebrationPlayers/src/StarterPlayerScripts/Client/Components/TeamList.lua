local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local PlayerComponent = require(script.Parent.Player)
local TeamHeaderComponent = require(script.Parent.TeamHeader)
local Player = Players.LocalPlayer

local DEV_GRP = 7
local DEV_LOWEST_RANK = 255

local New = Fusion.New
local Children = Fusion.Children
local Value = Fusion.Value
local ComputedPairs = Fusion.ComputedPairs
local Computed = Fusion.Computed
local OnChange = Fusion.OnChange

return function(props)
    local absoluteContentSize = Value(Vector2.new(0, 0))

    return New "Frame" {
        BackgroundTransparency = 1,
        Size = Computed(function()
            return UDim2.new(1, 0, 0, absoluteContentSize:get().Y)
        end),

        [Children] = {
            New "UIListLayout" {
                SortOrder = Enum.SortOrder.LayoutOrder,

                [OnChange "AbsoluteContentSize"] = function(newValue)
                    absoluteContentSize:set(newValue)
                end
            },

            Computed(function()
                if #Teams:GetTeams() > 0 then
                    return TeamHeaderComponent({
                        Color = props.Color,
                        Name = if props.Name == "@no_team" then "No Team" else props.Name,
                        Collapsed = props.Collapsed,
                        Count = #props.Players,
                    })
                else
                    return nil
                end
            end),

			ComputedPairs(props.Players, function(index, player)
				player:WaitForChild("leaderstats"):WaitForChild("Country")
				player:WaitForChild("leaderstats"):WaitForChild("Team")
				player:WaitForChild("leaderstats"):WaitForChild("Suspended")
				player:WaitForChild("leaderstats"):WaitForChild("Ping")
				player:WaitForChild("leaderstats"):WaitForChild("Staff")
				
				return PlayerComponent({
                    UserId = player.UserId,
                    Name = player.Name,
					Country = player.leaderstats.Country.Value,
					Staff = player.leaderstats.Staff.Value,
					Ping = player.leaderstats.Ping,
					Team = player.leaderstats.Team.Value,
					Suspended = player.leaderstats.Suspended.Value,
                    Order = Value(index),
                    AtTop = Value(true),
                    AtBottom = Computed(function()
                        return index == #props.Players
                    end),
                    Visible = Computed(function()
                        return not props.Collapsed:get()
                    end),
                })
            end)
        },
    }
end