local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local SoundGroup = SoundService.SoundGroup

local ClickSystem = SoundGroup.ClickSystem

local SucessClick = ClickSystem.Success

local Open = false

local Coins = script.Parent

local Icon = Coins.Icon

local function OnClicked()
	
	if Open == false then
		
		Coins:TweenPosition(UDim2.new(0, -175, 1, -86), "InOut","Quart", 0.8, true)
		
		SucessClick:Play()
		
		Open = true
		
	elseif Open == true then
		
		Coins:TweenPosition(UDim2.new(0, -10, 1, -86), "InOut","Quart", 0.8, true)
		
		SucessClick:Play()

		Open = false
	end
end

Icon.MouseButton1Click:Connect(OnClicked)