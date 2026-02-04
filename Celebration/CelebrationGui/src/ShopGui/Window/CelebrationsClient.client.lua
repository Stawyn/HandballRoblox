local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmotesSource = ReplicatedStorage:WaitForChild("EmotesSource")
local EmoteEvent = EmotesSource:WaitForChild("RE")

local allEmotes = EmotesSource:WaitForChild("Emotes")

local sFrame = script.Parent:WaitForChild("ShopFrame")
local iFrame = script.Parent.Parent:WaitForChild("InventoryFrame")

local emotesF = Players.LocalPlayer:WaitForChild("Emotes")

local playingEmotes = {}

local Coins = game.Players.LocalPlayer:WaitForChild("leaderstats"):WaitForChild("Coins")

function createInv()
	for i, child in pairs(iFrame.EmotesScroller:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	
	local btns = {}
	
	for i, emote in pairs(emotesF:GetChildren()) do
		local btn = script.PlayEmoteButton:Clone()
		local emoteN = emote.Name
		btn.Text = emoteN
		
		btn.MouseButton1Click:Connect(function()
		local char = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
		local animator: Animator = char:WaitForChild("Humanoid"):FindFirstChildOfClass("Animator")
			animator:LoadAnimation(emote):Play()
		end)
		
		table.insert(btns, btn)
	end
	
	table.sort(btns, function(a, b)
		return a.Text < b.Text
	end)
	
	for i, btn in pairs(btns) do
		btn.Parent = iFrame.EmotesScroller
	end
	
end

createInv()

function createShop()

	for i, child in pairs(sFrame.EmotesScroller:GetChildren()) do
		
		if child:IsA("TextButton") then
			
			child:Destroy()
		end
	end

	local btns = {}

	for i, emote in pairs(allEmotes:GetChildren()) do

		local btn = script.SelectEmoteButton:Clone()
		
		local emoteN = emote.Name
		
		btn.EmoteName.Text = emoteN
		
				
				
		local cam = Instance.new("Camera")
		
		cam.Parent = btn.EmotePreview
		
		btn.EmotePreview.CurrentCamera = cam
		
		
		local char = EmotesSource:FindFirstChild("PreviewCharacter"):Clone()
		
		char.Parent = btn.EmotePreview
		
		local hrp = char.HumanoidRootPart
		
		cam.CFrame = CFrame.new(hrp.Position + hrp.CFrame.LookVector * 5, hrp.Position)
		
		local price = emote.PRICE.Value
		
		btn.MouseButton1Click:Connect(function()
			
	    sFrame.SelectedEmoteFrame.EmoteName.Text = emoteN

			if not emotesF:FindFirstChild(emoteN) then
				
				sFrame.SelectedEmoteFrame.BuyButton.Text = "BUY for $" .. price
				
			else
				
				sFrame.SelectedEmoteFrame.BuyButton.Text = "OWNED"
			end
							
			sFrame.SelectedEmoteFrame.EmotePreview:ClearAllChildren()
					
			local cam2 = Instance.new("Camera")
			
			cam2.Parent = sFrame.SelectedEmoteFrame.EmotePreview
			
			sFrame.SelectedEmoteFrame.EmotePreview.CurrentCamera = cam2

			local wModel2 = Instance.new("WorldModel")
			
			local char2 = EmotesSource:FindFirstChild("PreviewCharacter"):Clone()
			
			char2.Parent = workspace

			local loadedAnim2 = char2.Humanoid:LoadAnimation(emote)
			
			loadedAnim2.Looped = true
			
			loadedAnim2:Play()
					
			wModel2.Parent = sFrame.SelectedEmoteFrame.EmotePreview
			
			char2.Parent = wModel2
		
			local hrp2 = char2.HumanoidRootPart
			
			cam2.CFrame = CFrame.new(hrp2.Position + hrp2.CFrame.LookVector * 5.2, hrp2.Position)
				
			sFrame.SelectedEmoteFrame.Visible = true
		end)

		table.insert(btns, btn)	
	end
	
	table.sort(btns, function(a, b)
		
		local aIndex = allEmotes[a.EmoteName.Text].PRICE.Value
		
		local bIndex = allEmotes[b.EmoteName.Text].PRICE.Value
		
		return aIndex < bIndex or aIndex == bIndex and a.EmoteName.Text < b.EmoteName.Text
	end)

	for i, btn in pairs(btns) do
		
		btn.Parent = sFrame.EmotesScroller
	end
end

createShop()

sFrame.SelectedEmoteFrame.BuyButton.MouseButton1Click:Connect(function()

	if sFrame.SelectedEmoteFrame.BuyButton.Text ~= "OWNED" then

		local emoteN = sFrame.SelectedEmoteFrame.EmoteName.Text
		local emotePrice = allEmotes[emoteN].PRICE.Value

		if Coins.Value >= emotePrice then
			EmoteEvent:FireServer(emoteN)
			-- ???
			sFrame.SelectedEmoteFrame.BuyButton.Text = "OWNED"
		end
	end
end)

emotesF.ChildAdded:Connect(createInv)
emotesF.ChildRemoved:Connect(createInv)

allEmotes.ChildAdded:Connect(createShop)
allEmotes.ChildRemoved:Connect(createShop)