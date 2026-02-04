--[[
    ================================================================================
    MÓDULO: CelebrationsClient
    ================================================================================
    Descrição: Interface de loja de celebrações e controle de emotes.
    Funcionalidades: - Loja de emotes
                     - Inventário de emotes comprados
                     - Seleção de emote ativo (tecla B ou botão mobile)
                     - Blur quando GUI aberta
                     - Esconder tools quando GUI aberta
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: SERVIÇOS E DEPENDÊNCIAS
--// ============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--// ============================================================================
--// SETOR: DETECÇÃO DE DISPOSITIVO
--// ============================================================================

local IS_MOBILE = UserInputService.TouchEnabled 
	and not UserInputService.KeyboardEnabled 
	and not GuiService:IsTenFootInterface()

--// ============================================================================
--// SETOR: REFERÊNCIAS
--// ============================================================================

local EmotesSource = ReplicatedStorage:WaitForChild("EmotesSource")
local EmoteEvent = EmotesSource:WaitForChild("RE")
local allEmotes = EmotesSource:WaitForChild("Emotes")

-- Estrutura: ShopGui > Window > MainFrame > Content > (ShopArea, Sidebar, PreviewPanel)
-- Com init.client.luau, script É o CelebrationsClient, então script.Parent = Window
local Window = script.Parent
local MainFrame = Window:WaitForChild("MainFrame")
local Content = MainFrame:WaitForChild("Content")

-- Painéis principais
local ShopArea = Content:WaitForChild("ShopArea")
local PreviewPanel = Content:WaitForChild("PreviewPanel")

-- Header (close button)
local Header = MainFrame:WaitForChild("Header")
local CloseButton = Header:WaitForChild("CloseButton")

-- Elementos dentro dos painéis
local ShopScroller = ShopArea:WaitForChild("ShopScroller")
local EmoteName = PreviewPanel:WaitForChild("EmoteName")
local EmotePreview = PreviewPanel:WaitForChild("EmotePreview")
local BuyButton = PreviewPanel:WaitForChild("BuyButton")

local emotesF = LocalPlayer:WaitForChild("Emotes")
local Coins = LocalPlayer:WaitForChild("leaderstats"):WaitForChild("Coins")

--// ============================================================================
--// SETOR: BLUR EFFECT
--// ============================================================================

local BlurEffect = Lighting:FindFirstChild("ShopBlur")
if not BlurEffect then
	BlurEffect = Instance.new("BlurEffect")
	BlurEffect.Name = "ShopBlur"
	BlurEffect.Size = 0
	BlurEffect.Enabled = false
	BlurEffect.Parent = Lighting
end

local function setBlurEnabled(enabled: boolean)
	BlurEffect.Enabled = enabled
	local targetSize = if enabled then 24 else 0
	local tween = TweenService:Create(BlurEffect, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
		Size = targetSize
	})
	tween:Play()
end

--// ============================================================================
--// SETOR: FECHAR LOJA (CloseButton)
--// ============================================================================

CloseButton.MouseButton1Click:Connect(function()
	Window.Visible = false
end)

--// ============================================================================
--// SETOR: TOOL HIDING
--// ============================================================================

local previousEquippedTool: Tool? = nil

local function setToolsHidden(hidden: boolean)
	local character = LocalPlayer.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	if hidden then
		local currentTool = character:FindFirstChildOfClass("Tool")
		if currentTool then
			previousEquippedTool = currentTool
			humanoid:UnequipTools()
		end
	else
		if previousEquippedTool and previousEquippedTool.Parent == LocalPlayer.Backpack then
			humanoid:EquipTool(previousEquippedTool)
		end
		previousEquippedTool = nil
	end
end

--// ============================================================================
--// SETOR: ESTADO
--// ============================================================================

local selectedEmote: string? = nil
local isPlayingEmote = false

--// ============================================================================
--// SETOR: INVENTÁRIO
--// ============================================================================

-- Inventário removido - equip é feito diretamente clicando no emote na loja
local function updateEquipHighlights()
	-- Atualiza visual de todos os cards na loja
	for _, btn in pairs(ShopScroller:GetChildren()) do
		if btn:IsA("TextButton") and btn:FindFirstChild("EmoteName") then
			local emoteN = btn.EmoteName.Text
			if emotesF:FindFirstChild(emoteN) then
				-- Owned - highlight diferente se equipado
				if selectedEmote == emoteN then
					btn.BackgroundColor3 = Color3.fromRGB(0, 170, 127)
				else
					btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
				end
			else
				btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
			end
		end
	end
end

--// ============================================================================
--// SETOR: LOJA
--// ============================================================================

function createShop()
	for _, child in pairs(ShopScroller:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	local btns = {}

	for _, emote in pairs(allEmotes:GetChildren()) do
		if not emote:IsA("Animation") then continue end
		
		local btn = script:FindFirstChild("SelectEmoteButton")
		if btn then
			btn = btn:Clone()
		else
			-- Criar card simples se template não existir
			btn = Instance.new("TextButton")
			btn.Size = UDim2.new(0, 85, 0, 100)
			btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
			btn.Text = ""
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 4)
			corner.Parent = btn
			
			local nameLabel = Instance.new("TextLabel")
			nameLabel.Name = "EmoteName"
			nameLabel.BackgroundTransparency = 1
			nameLabel.Size = UDim2.new(1, 0, 0.2, 0)
			nameLabel.Position = UDim2.new(0, 0, 0.75, 0)
			nameLabel.TextColor3 = Color3.new(1, 1, 1)
			nameLabel.Font = Enum.Font.GothamMedium
			nameLabel.TextSize = 10
			nameLabel.Parent = btn
			
			local preview = Instance.new("ViewportFrame")
			preview.Name = "EmotePreview"
			preview.BackgroundTransparency = 0.5
			preview.Size = UDim2.new(0.85, 0, 0.55, 0)
			preview.Position = UDim2.new(0.075, 0, 0.1, 0)
			preview.Parent = btn
		end
		
		local emoteN = emote.Name
		
		if btn:FindFirstChild("EmoteName") then
			btn.EmoteName.Text = emoteN
		end

		if btn:FindFirstChild("EmotePreview") then
			local cam = Instance.new("Camera")
			cam.Parent = btn.EmotePreview
			btn.EmotePreview.CurrentCamera = cam

			local previewChar = EmotesSource:FindFirstChild("PreviewCharacter")
			if previewChar then
				local char = previewChar:Clone()
				char.Parent = btn.EmotePreview
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if hrp then
					cam.CFrame = CFrame.new(hrp.Position + hrp.CFrame.LookVector * 5, hrp.Position)
				end
			end
		end

		local priceVal = emote:FindFirstChild("PRICE")
		local price = priceVal and priceVal.Value or 0

		btn.MouseButton1Click:Connect(function()
			EmoteName.Text = emoteN

			if not emotesF:FindFirstChild(emoteN) then
				BuyButton.Text = "BUY for $" .. price
				BuyButton.BackgroundColor3 = Color3.fromRGB(241, 196, 15)
			else
				if selectedEmote == emoteN then
					BuyButton.Text = "✓ EQUIPPED"
					BuyButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
				else
					BuyButton.Text = "EQUIP"
					BuyButton.BackgroundColor3 = Color3.fromRGB(0, 170, 127)
				end
			end

			EmotePreview:ClearAllChildren()

			local cam2 = Instance.new("Camera")
			cam2.Parent = EmotePreview
			EmotePreview.CurrentCamera = cam2

			local wModel2 = Instance.new("WorldModel")

			local previewChar2 = EmotesSource:FindFirstChild("PreviewCharacter")
			if previewChar2 then
				local char2 = previewChar2:Clone()
				char2.Parent = workspace

				local hum = char2:FindFirstChild("Humanoid")
				if hum then
					local loadedAnim2 = hum:LoadAnimation(emote)
					loadedAnim2.Looped = true
					loadedAnim2:Play()
				end

				wModel2.Parent = EmotePreview
				char2.Parent = wModel2

				local hrp2 = char2:FindFirstChild("HumanoidRootPart")
				if hrp2 then
					cam2.CFrame = CFrame.new(hrp2.Position + hrp2.CFrame.LookVector * 5.2, hrp2.Position)
				end
			end
		end)

		btn.LayoutOrder = price
		table.insert(btns, btn)
	end

	table.sort(btns, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)

	for _, btn in pairs(btns) do
		btn.Parent = ShopScroller
	end
end

createShop()

--// ============================================================================
--// SETOR: COMPRA
--// ============================================================================

BuyButton.MouseButton1Click:Connect(function()
	local emoteN = EmoteName.Text
	local buttonText = BuyButton.Text

	if buttonText:find("BUY") then
		local emoteAsset = allEmotes:FindFirstChild(emoteN)
		local priceVal = emoteAsset and emoteAsset:FindFirstChild("PRICE")
		local emotePrice = priceVal and priceVal.Value or 0

		if Coins.Value >= emotePrice then
			EmoteEvent:FireServer("BUY", emoteN)
			BuyButton.Text = "EQUIP"
			BuyButton.BackgroundColor3 = Color3.fromRGB(0, 170, 127)
			task.delay(0.3, function()
				updateEquipHighlights()
				createShop()
			end)
		else
			BuyButton.Text = "NOT ENOUGH 💰"
			BuyButton.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
			task.delay(1.5, function()
				BuyButton.Text = "BUY for $" .. emotePrice
				BuyButton.BackgroundColor3 = Color3.fromRGB(241, 196, 15)
			end)
		end
	elseif buttonText:find("EQUIP") then
		selectedEmote = emoteN
		EmoteEvent:FireServer("SELECT", emoteN)
		BuyButton.Text = "✓ EQUIPPED"
		BuyButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
		updateEquipHighlights()
		print("Emote equipado: " .. emoteN)
	end
end)

--// ============================================================================
--// SETOR: FUNÇÃO TOCAR EMOTE
--// ============================================================================

local function playEmote()
	if isPlayingEmote then return end

	if not selectedEmote then
		warn("Nenhum emote selecionado.")
		return
	end

	if not emotesF:FindFirstChild(selectedEmote) then
		warn("Você não possui este emote.")
		return
	end

	isPlayingEmote = true

	local character = LocalPlayer.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local animator = humanoid:FindFirstChildOfClass("Animator")
			if animator then
				local emoteAsset = allEmotes:FindFirstChild(selectedEmote)
				if emoteAsset then
					local track = animator:LoadAnimation(emoteAsset)
					track:Play()

					track.Stopped:Once(function()
						isPlayingEmote = false
					end)

					task.delay(5, function()
						isPlayingEmote = false
					end)
				end
			end
		end
	end

	EmoteEvent:FireServer("PLAY")
end

--// ============================================================================
--// SETOR: TECLA B - ATIVAR EMOTE (PC)
--// ============================================================================

if not IS_MOBILE then
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.B then
			playEmote()
		end
	end)
end

--// ============================================================================
--// SETOR: BOTÃO MOBILE - ATIVAR EMOTE
--// ============================================================================

if IS_MOBILE then
	local MobileEmoteButton = Instance.new("TextButton")
	MobileEmoteButton.Name = "MobileEmoteButton"
	MobileEmoteButton.BackgroundColor3 = Color3.fromRGB(0, 170, 127)
	MobileEmoteButton.AnchorPoint = Vector2.new(1, 1)
	MobileEmoteButton.Position = UDim2.new(1, -15, 1, -100)
	MobileEmoteButton.Size = UDim2.new(0, 60, 0, 60)
	MobileEmoteButton.Font = Enum.Font.GothamBold
	MobileEmoteButton.Text = "🎉"
	MobileEmoteButton.TextColor3 = Color3.new(1, 1, 1)
	MobileEmoteButton.TextSize = 28
	MobileEmoteButton.ZIndex = 200
	MobileEmoteButton.Parent = Window.Parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = MobileEmoteButton

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 200, 150)
	stroke.Thickness = 2
	stroke.Parent = MobileEmoteButton

	MobileEmoteButton.MouseButton1Click:Connect(function()
		playEmote()
	end)
end

--// ============================================================================
--// SETOR: VISIBILIDADE - BLUR E TOOLS
--// ============================================================================

Window:GetPropertyChangedSignal("Visible"):Connect(function()
	setBlurEnabled(Window.Visible)
	setToolsHidden(Window.Visible)
end)

Window.Destroying:Connect(function()
	if BlurEffect then
		BlurEffect.Size = 0
		BlurEffect.Enabled = false
	end
end)

--// ============================================================================
--// SETOR: EVENTOS DE ATUALIZAÇÃO
--// ============================================================================

emotesF.ChildAdded:Connect(updateEquipHighlights)
emotesF.ChildRemoved:Connect(updateEquipHighlights)

allEmotes.ChildAdded:Connect(createShop)
allEmotes.ChildRemoved:Connect(createShop)

print("[CelebrationsClient] Carregado! Device:", if IS_MOBILE then "Mobile 📱" else "PC 🖥️")