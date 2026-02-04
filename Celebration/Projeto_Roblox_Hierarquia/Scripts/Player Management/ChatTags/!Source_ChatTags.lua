local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local ChatService = require(ServerScriptService:WaitForChild("ChatServiceRunner"):WaitForChild("ChatService"))

function CheckChatTags(Player)
	local Speaker = ChatService:GetSpeaker(Player)
	if Players[Player].Name == "Mzxtheus" then
		Speaker:SetExtraData("Tags", {{TagText = 'DEV', TagColor = Color3.fromRGB(0, 255, 238)}})
	end
end

ChatService.SpeakerAdded:Connect(CheckChatTags)
