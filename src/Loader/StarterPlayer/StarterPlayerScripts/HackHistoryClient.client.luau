--[[
	================================================================================
	SCRIPT: HackHistoryClient (Menu de Histórico de Violações)
	================================================================================
	
	Descrição:
		Menu estilo stats que mostra histórico de violações de hack.
		Acessível via F5 ou botào no topbar (para Officials).
		Mostra: jogador, tipo, detalhes, hora, total de violações.
	
	Autor: Sistema ABH
	================================================================================
]]

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Teams = game:GetService("Teams")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local isMobile = UserInputService.TouchEnabled

--// Configuration //--
local THEME = {
	Background = Color3.fromRGB(15, 15, 20),
	Header = Color3.fromRGB(35, 20, 25),
	RowEven = Color3.fromRGB(25, 18, 22),
	RowOdd = Color3.fromRGB(20, 15, 18),
	Accent = Color3.fromRGB(255, 80, 80),
	Text = Color3.fromRGB(255, 255, 255),
	TextDim = Color3.fromRGB(160, 160, 170),
	Border = Color3.fromRGB(60, 30, 40),
}

local VIOLATION_COLORS = {
	SPEED_HACK = Color3.fromRGB(255, 80, 80),
	TELEPORT = Color3.fromRGB(255, 150, 50),
	FLY_HACK = Color3.fromRGB(180, 100, 255),
	KEEPER_HBE = Color3.fromRGB(255, 200, 50),
	RATE_LIMIT = Color3.fromRGB(100, 150, 255),
	INVALID_THROW = Color3.fromRGB(150, 255, 150),
	DEFAULT = Color3.fromRGB(255, 80, 80)
}

local FONTS = {
	Regular = Enum.Font.Gotham,
	Bold = Enum.Font.GothamBold,
}

--// State //--
local HackHistory = {} -- {playerName, playerId, violationType, details, time, totalViolations}
local GuiInstance = nil
local ContentFrame = nil
local BlurEffect = nil
local RowPool = {}

--// Network //--
-- Espera o Loader terminar
ReplicatedStorage:WaitForChild("LoaderReady")
local NETWORK_FOLDER = ReplicatedStorage:WaitForChild("Network") :: Folder
local LEAGUE_EVENT = NETWORK_FOLDER:WaitForChild("LeagueEvent") :: RemoteEvent

--// Helper Functions //--
local function formatTime(timestamp)
	local date = os.date("*t", timestamp)
	return string.format("%02d:%02d:%02d", date.hour, date.min, date.sec)
end

local function isOfficial()
	local team = LocalPlayer.Team
	return team and team.Name == "Officials"
end

local function getOrCreateRow(index)
	if RowPool[index] then return RowPool[index] end

	local row = Instance.new("Frame")
	row.Name = "Row_" .. index
	row.Size = UDim2.new(1, 0, 0, isMobile and 50 or 60)
	row.BorderSizePixel = 0
	row.Parent = ContentFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = row

	-- Barra colorida à esquerda
	local colorBar = Instance.new("Frame")
	colorBar.Name = "ColorBar"
	colorBar.Size = UDim2.new(0, 4, 1, -4)
	colorBar.Position = UDim2.new(0, 2, 0, 2)
	colorBar.BorderSizePixel = 0
	colorBar.Parent = row

	local colorCorner = Instance.new("UICorner")
	colorCorner.CornerRadius = UDim.new(0, 2)
	colorCorner.Parent = colorBar

	-- Tipo de violação
	local typeLabel = Instance.new("TextLabel")
	typeLabel.Name = "Type"
	typeLabel.Size = UDim2.new(0, 120, 0, 20)
	typeLabel.Position = UDim2.new(0, 15, 0, 5)
	typeLabel.BackgroundTransparency = 1
	typeLabel.Font = FONTS.Bold
	typeLabel.TextSize = isMobile and 12 or 14
	typeLabel.TextXAlignment = Enum.TextXAlignment.Left
	typeLabel.Parent = row

	-- Nome do jogador
	local playerLabel = Instance.new("TextLabel")
	playerLabel.Name = "Player"
	playerLabel.Size = UDim2.new(0, 150, 0, 18)
	playerLabel.Position = UDim2.new(0, 15, 0, isMobile and 26 or 28)
	playerLabel.BackgroundTransparency = 1
	playerLabel.Font = FONTS.Regular
	playerLabel.TextSize = isMobile and 11 or 13
	playerLabel.TextColor3 = THEME.Text
	playerLabel.TextXAlignment = Enum.TextXAlignment.Left
	playerLabel.Parent = row

	-- Detalhes
	local detailsLabel = Instance.new("TextLabel")
	detailsLabel.Name = "Details"
	detailsLabel.Size = UDim2.new(0.4, 0, 0, 18)
	detailsLabel.Position = UDim2.new(0, 170, 0, isMobile and 26 or 28)
	detailsLabel.BackgroundTransparency = 1
	detailsLabel.Font = FONTS.Regular
	detailsLabel.TextSize = isMobile and 10 or 12
	detailsLabel.TextColor3 = THEME.TextDim
	detailsLabel.TextXAlignment = Enum.TextXAlignment.Left
	detailsLabel.TextTruncate = Enum.TextTruncate.AtEnd
	detailsLabel.Parent = row

	-- Hora
	local timeLabel = Instance.new("TextLabel")
	timeLabel.Name = "Time"
	timeLabel.Size = UDim2.new(0, 80, 0, 20)
	timeLabel.Position = UDim2.new(1, -90, 0, 5)
	timeLabel.BackgroundTransparency = 1
	timeLabel.Font = FONTS.Regular
	timeLabel.TextSize = isMobile and 10 or 12
	timeLabel.TextColor3 = THEME.TextDim
	timeLabel.TextXAlignment = Enum.TextXAlignment.Right
	timeLabel.Parent = row

	-- Contador de violações
	local countBadge = Instance.new("TextLabel")
	countBadge.Name = "Count"
	countBadge.Size = UDim2.new(0, 28, 0, 22)
	countBadge.Position = UDim2.new(1, -90, 0, isMobile and 26 or 30)
	countBadge.BackgroundTransparency = 0.3
	countBadge.Font = FONTS.Bold
	countBadge.TextSize = isMobile and 10 or 12
	countBadge.TextColor3 = THEME.Text
	countBadge.Parent = row

	local countCorner = Instance.new("UICorner")
	countCorner.CornerRadius = UDim.new(0, 4)
	countCorner.Parent = countBadge

	RowPool[index] = row
	return row
end

local function updateView()
	if not ContentFrame then return end

	for i = 1, math.max(#HackHistory, #RowPool) do
		local row = getOrCreateRow(i)
		local data = HackHistory[#HackHistory - i + 1] -- Mais recente primeiro

		if data then
			row.Visible = true
			row.BackgroundColor3 = (i % 2 == 0) and THEME.RowEven or THEME.RowOdd

			local color = VIOLATION_COLORS[data.violationType] or VIOLATION_COLORS.DEFAULT

			row.ColorBar.BackgroundColor3 = color
			row.Type.Text = "⚠️ " .. (data.violationType or ""):gsub("_", " ")
			row.Type.TextColor3 = color
			row.Player.Text = "👤 " .. (data.playerName or "Unknown")
			row.Details.Text = data.details or ""
			row.Time.Text = "🕐 " .. formatTime(data.time or os.time())
			row.Count.Text = tostring(data.totalViolations or 1)
			row.Count.BackgroundColor3 = color
		else
			row.Visible = false
		end
	end

	ContentFrame.CanvasSize = UDim2.new(0, 0, 0, #HackHistory * (isMobile and 55 or 65))
end

local function toggleUI(state)
	if not GuiInstance then return end

	if state == nil then state = not GuiInstance.Enabled end
	GuiInstance.Enabled = state

	if state then
		if BlurEffect then
			BlurEffect.Enabled = true
			TweenService:Create(BlurEffect, TweenInfo.new(0.3), {Size = 10}):Play()
		end
		updateView()
	else
		if BlurEffect then
			local t = TweenService:Create(BlurEffect, TweenInfo.new(0.2), {Size = 0})
			t:Play()
			t.Completed:Connect(function()
				if not GuiInstance.Enabled then
					BlurEffect.Enabled = false
				end
			end)
		end
	end
end

local function createUI()
	if GuiInstance then GuiInstance:Destroy() end

	-- Setup Blur
	BlurEffect = Lighting:FindFirstChild("HackHistoryBlur")
	if not BlurEffect then
		BlurEffect = Instance.new("BlurEffect")
		BlurEffect.Name = "HackHistoryBlur"
		BlurEffect.Size = 0
		BlurEffect.Enabled = false
		BlurEffect.Parent = Lighting
	end

	local sg = Instance.new("ScreenGui")
	sg.Name = "HackHistoryGui"
	sg.ResetOnSpawn = false
	sg.Enabled = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"

	if isMobile then
		mainFrame.Size = UDim2.new(0.95, 0, 0.7, 0)
		mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
		mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	else
		mainFrame.Size = UDim2.new(0, 600, 0, 450)
		mainFrame.Position = UDim2.new(0.5, -300, 0.5, -225)
	end

	mainFrame.BackgroundColor3 = THEME.Background
	mainFrame.BackgroundTransparency = 0.05
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = sg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = mainFrame

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = THEME.Border
	stroke.Parent = mainFrame

	-- Top Bar
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, 0, 0, isMobile and 40 or 50)
	topBar.BackgroundColor3 = THEME.Header
	topBar.BorderSizePixel = 0
	topBar.ZIndex = 2
	topBar.Parent = mainFrame

	local topCorner = Instance.new("UICorner")
	topCorner.CornerRadius = UDim.new(0, 10)
	topCorner.Parent = topBar

	-- Título
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -60, 1, 0)
	titleLabel.Position = UDim2.new(0, 15, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "🛡️ HISTÓRICO DE VIOLAÇÕES"
	titleLabel.TextSize = isMobile and 14 or 18
	titleLabel.Font = FONTS.Bold
	titleLabel.TextColor3 = THEME.Accent
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = topBar

	-- Contador total
	local totalLabel = Instance.new("TextLabel")
	totalLabel.Name = "Total"
	totalLabel.Size = UDim2.new(0, 80, 0, 24)
	totalLabel.Position = UDim2.new(1, -140, 0.5, -12)
	totalLabel.BackgroundColor3 = THEME.Accent
	totalLabel.BackgroundTransparency = 0.3
	totalLabel.Text = tostring(#HackHistory) .. " alertas"
	totalLabel.TextSize = isMobile and 10 or 12
	totalLabel.Font = FONTS.Bold
	totalLabel.TextColor3 = THEME.Text
	totalLabel.Parent = topBar

	local totalCorner = Instance.new("UICorner")
	totalCorner.CornerRadius = UDim.new(0, 6)
	totalCorner.Parent = totalLabel

	-- Botào de fechar
	local closeBtn = Instance.new("TextButton")
	closeBtn.Text = "X"
	closeBtn.Size = UDim2.new(0, isMobile and 30 or 36, 0, isMobile and 30 or 36)
	closeBtn.Position = UDim2.new(1, isMobile and -38 or -46, 0.5, isMobile and -15 or -18)
	closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
	closeBtn.TextColor3 = THEME.Text
	closeBtn.Font = FONTS.Bold
	closeBtn.TextSize = isMobile and 14 or 18
	closeBtn.Parent = topBar

	local closeBtnCorner = Instance.new("UICorner")
	closeBtnCorner.CornerRadius = UDim.new(0, 6)
	closeBtnCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		toggleUI(false)
	end)

	-- Conteúdo (scroll)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "List"
	scroll.Size = UDim2.new(1, -10, 1, isMobile and -50 or -60)
	scroll.Position = UDim2.new(0, 5, 0, isMobile and 45 or 55)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = isMobile and 4 or 6
	scroll.ScrollBarImageColor3 = THEME.Accent
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.Parent = mainFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 5)
	listLayout.Parent = scroll

	ContentFrame = scroll
	GuiInstance = sg
	RowPool = {}
	sg.Parent = PlayerGui

	-- Atualiza contador
	local function updateTotal()
		totalLabel.Text = tostring(#HackHistory) .. " alertas"
	end

	-- Conecta atualização do contador
	spawn(function()
		while GuiInstance and GuiInstance.Parent do
			updateTotal()
			task.wait(1)
		end
	end)
end

--// Evento de hack recebido //--
local function onHackAlert(action, data)
	if action == "HACK_ALERT" then
		table.insert(HackHistory, {
			playerName = data.playerName,
			playerId = data.playerId,
			violationType = data.violationType,
			details = data.details,
			time = data.time or os.time(),
			totalViolations = data.totalViolations or 1
		})

		-- Limita histórico a 50 entradas
		while #HackHistory > 50 do
			table.remove(HackHistory, 1)
		end

		-- Atualiza se UI estiver aberta
		if GuiInstance and GuiInstance.Enabled then
			updateView()
		end
	end
end

--// Inicialização //--
local function init()
	createUI()

	-- Conecta ao evento de rede
	LEAGUE_EVENT.OnClientEvent:Connect(onHackAlert)

	-- Hotkey F5 para toggle (só Officials)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.F5 then
			if isOfficial() then
				toggleUI()
			end
		end
	end)

	-- Toggle via BindableEvent
	local toggleEvent = ReplicatedStorage:FindFirstChild("ToggleHackHistory")
	if not toggleEvent then
		toggleEvent = Instance.new("BindableEvent")
		toggleEvent.Name = "ToggleHackHistory"
		toggleEvent.Parent = ReplicatedStorage
	end

	toggleEvent.Event:Connect(function()
		if isOfficial() then
			toggleUI()
		end
	end)

	-- Botào no Topbar usando TopbarPlus/Icon
	task.spawn(function()
		-- Espera o TopbarPlus/Icon carregar
		local Icon
		pcall(function()
			Icon = require(ReplicatedStorage:WaitForChild("Utilities"):WaitForChild("Icon", 10))
		end)

		if not Icon then
			warn("[HackHistoryClient] TopbarPlus/Icon não encontrado, usando apenas F5")
			return
		end

		-- Cria o ícone no topbar
		local hackIcon = Icon.new()
		hackIcon:setLabel("🛡️")
		hackIcon:setName("HackHistory")
		hackIcon:setOrder(99) -- Posição no topbar
		hackIcon:setEnabled(false) -- Começa escondido

		-- Mostra/esconde baseado no time
		local function updateIconVisibility()
			if isOfficial() then
				hackIcon:setEnabled(true)
			else
				hackIcon:setEnabled(false)
				if GuiInstance and GuiInstance.Enabled then
					toggleUI(false)
				end
			end
		end

		-- Verifica inicialmente
		updateIconVisibility()

		-- Verifica quando muda de time
		LocalPlayer:GetPropertyChangedSignal("Team"):Connect(updateIconVisibility)

		-- Toggle ao clicar
		hackIcon.selected:Connect(function()
			toggleUI(true)
		end)

		hackIcon.deselected:Connect(function()
			toggleUI(false)
		end)

		-- Sincroniza com estado do menu
		if GuiInstance then
			GuiInstance:GetPropertyChangedSignal("Enabled"):Connect(function()
				if GuiInstance.Enabled and not hackIcon.isSelected then
					hackIcon:select()
				elseif not GuiInstance.Enabled and hackIcon.isSelected then
					hackIcon:deselect()
				end
			end)
		end

		print("[HackHistoryClient] ✅ Botào 🛡️ adicionado no topbar")
	end)

	print("[HackHistoryClient] ✅ Menu de histórico inicializado (F5 para abrir)")
end

init()
