local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local StatUtils = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Implementation"):WaitForChild("StatUtils"))
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local isMobile = UserInputService.TouchEnabled

--// Configuration //--
local THEME = {
	Background = Color3.fromRGB(15, 15, 20),
	Header = Color3.fromRGB(25, 25, 30),
	RowEven = Color3.fromRGB(22, 22, 28),
	RowOdd = Color3.fromRGB(18, 18, 24),
	Accent = Color3.fromRGB(0, 170, 255),
	Text = Color3.fromRGB(255, 255, 255),
	TextDim = Color3.fromRGB(160, 160, 170),
	Border = Color3.fromRGB(45, 45, 55),
	SelectedTab = Color3.fromRGB(0, 130, 200),
	UnselectedTab = Color3.fromRGB(30, 30, 40),
}

local COLORS = {
	Attack = Color3.fromHex("#4facfe"),
	Defense = Color3.fromHex("#ff6b6b"),
	GK = Color3.fromHex("#f093fb"),
	Tech = Color3.fromHex("#a8ff78"),
	MVP = Color3.fromHex("#ffd700"),
	Normal = Color3.fromRGB(255, 255, 255),
	Offline = Color3.fromHex("#2ecc71"),

	TeamHome = Color3.fromHex("#4facfe"),
	TeamHomeDark = Color3.fromHex("#2b6fb3"),
	TeamAway = Color3.fromHex("#ff6b6b"),
	TeamAwayDark = Color3.fromHex("#8b2b2b")
}

local FONTS = {
	Regular = Enum.Font.Gotham,
	Bold = Enum.Font.GothamBold,
}

local success, _ = pcall(function() return Enum.Font.GothamSSm end)
if success then
	FONTS.Regular = Enum.Font.GothamSSm
	FONTS.Bold = Enum.Font.GothamSSmBold
end

-- Column Definition (Organized by Color)
local COLUMNS = {
	{Id = "Player",     Name = "JOGADOR",   Width = 0.18, Color = THEME.Text, Category = ""},
	{Id = "MVP",        Name = "MVP",       Width = 0.06, Color = COLORS.MVP,       Format = "Number", Category = ""},

	-- Ataque (Azul)
	{Id = "Goals",      Name = "GOLS",      Width = 0.05, Color = COLORS.Attack,    Format = "Number", Category = "ATAQUE"},
	{Id = "Assists",    Name = "ASSIST",    Width = 0.05, Color = COLORS.Attack,    Format = "Number", Category = "ATAQUE"},
	{Id = "SOG",        Name = "SOG",       Width = 0.05, Color = COLORS.Attack,    Format = "Number", Category = "ATAQUE"},
	{Id = "FastBreakGoals", Name = "CA",    Width = 0.04, Color = COLORS.Attack,    Format = "Number", Category = "ATAQUE"},
	{Id = "EficPct",    Name = "EF%",       Width = 0.06, Color = COLORS.Attack,    Format = "Percent", Category = "ATAQUE"},

	-- Posse/Tech (Verde)
	{Id = "Passes",     Name = "PASSES",    Width = 0.08, Color = COLORS.Tech,      Format = "CompAtt", Category = "Tàƒâ€°CNICO"},
	{Id = "PossessionTime", Name = "POSSE", Width = 0.07, Color = COLORS.Tech,      Format = "FloatShort", Category = "Tàƒâ€°CNICO"},

	-- Geral (Vermelho)
	{Id = "Steals",     Name = "STL",       Width = 0.05, Color = COLORS.Defense,   Format = "Number", Category = "GERAL"},
	{Id = "Turnovers",  Name = "ERR",       Width = 0.06, Color = COLORS.Defense,   Format = "Number", Category = "GERAL"},

	-- Goleiro (Rosa)
	{Id = "Saves",      Name = "DEF",       Width = 0.06, Color = COLORS.GK,        Format = "Number", Category = "DEFESA"},
	{Id = "GoalsConceded", Name = "GS",     Width = 0.06, Color = COLORS.GK,        Format = "Number", Category = "DEFESA"},
	{Id = "DefPct",     Name = "EF%",      Width = 0.06, Color = COLORS.GK,        Format = "Percent", Category = "DEFESA"},
	{Id = "GKAssists",  Name = "GKA",       Width = 0.07, Color = COLORS.GK,        Format = "Number", Category = "DEFESA"},
}

--// State //--
local CurrentData = {}
local CurrentView = "Total"
local CurrentSortColumn = "MVP"
local SortDescending = true
local GuiInstance = nil
local ContentFrame = nil
local RowPool = {}
local BlurEffect = nil

--// Forward Declarations //--
local createUI

--// Global Toggle Function (accessible from Topbar) //-
function _G.ToggleStatsUI()
	if not GuiInstance then createUI() end
	local statsGui = PlayerGui:FindFirstChild("StatsGui")
	if statsGui then
		statsGui.Enabled = not statsGui.Enabled
		if statsGui.Enabled then
			BlurEffect = Lighting:FindFirstChild("StatsBlur")
			if not BlurEffect then
				BlurEffect = Instance.new("BlurEffect")
				BlurEffect.Name = "StatsBlur"
				BlurEffect.Size = 0
				BlurEffect.Parent = Lighting
			end
			BlurEffect.Enabled = true
			TweenService:Create(BlurEffect, TweenInfo.new(0.3), {Size = 15}):Play()
		end
	end
end


--// Helper Functions //--

local function formatNumber(val)
	return tostring(math.floor(val or 0))
end

local function formatPercent(val)
	if not val then return "0%" end
	return string.format("%.0f%%", val)
end

local function nameColorForPlayer(player)
	if not player or not player.Team then return THEME.Text end
	local tname = player.Team.Name or ""
	if tname == "-Away Goalkeeper" then return COLORS.TeamAwayDark end
	if tname == "-Home Goalkeeper" then return COLORS.TeamHomeDark end
	if tname:find("Away") then return COLORS.TeamAway end
	if tname:find("Home") then return COLORS.TeamHome end
	return THEME.Text
end

local function getOrCreateRow(index)
	if RowPool[index] then return RowPool[index] end

	local row = Instance.new("Frame")
	row.Name = "Row_" .. index
	row.Size = UDim2.new(1, 0, 0, isMobile and 24 or 34)
	row.BorderSizePixel = 0
	row.Parent = ContentFrame

	local currentX = 0
	for i, col in ipairs(COLUMNS) do
		local cell = Instance.new("TextLabel")
		cell.Name = col.Id
		cell.Size = UDim2.new(col.Width, 0, 1, 0)
		cell.Position = UDim2.new(currentX, 0, 0, 0)
		cell.BackgroundTransparency = 1
		cell.TextColor3 = col.Color
		cell.Font = (col.Id == "Player" or col.Id == "MVP") and FONTS.Bold or FONTS.Regular
		cell.TextSize = isMobile and 11 or 14
		cell.TextXAlignment = Enum.TextXAlignment.Center

		if col.Id == "Player" then
			cell.TextXAlignment = Enum.TextXAlignment.Left
			local padding = Instance.new("UIPadding")
			padding.PaddingLeft = UDim.new(0, isMobile and 8 or 20) -- More padding for name
			padding.Parent = cell
		end

		cell.Parent = row

		-- Vertical Divider
		if i < #COLUMNS then
			local divider = Instance.new("Frame")
			divider.Name = "Divider"
			divider.Size = UDim2.new(0, 1, 0.4, 0)
			divider.Position = UDim2.new(1, 0, 0.3, 0)
			divider.BackgroundColor3 = THEME.Border
			divider.BackgroundTransparency = 0.5
			divider.BorderSizePixel = 0
			divider.Parent = cell
		end

		currentX = currentX + col.Width
	end

	local line = Instance.new("Frame")
	line.Name = "Line"
	line.Size = UDim2.new(1, 0, 0, 1)
	line.Position = UDim2.new(0, 0, 1, -1)
	line.BackgroundColor3 = THEME.Border
	line.BackgroundTransparency = 0.8
	line.BorderSizePixel = 0
	line.Parent = row

	RowPool[index] = row
	return row
end

local function updateView()
	if not ContentFrame then return end

	local displayData = {}
	local allUserIds = {}
	if CurrentData[1] then for uid, _ in pairs(CurrentData[1]) do allUserIds[uid] = true end end
	if CurrentData[2] then for uid, _ in pairs(CurrentData[2]) do allUserIds[uid] = true end end

	for uidStr, _ in pairs(allUserIds) do
		local s1 = (CurrentData[1] and CurrentData[1][uidStr])
		local s2 = (CurrentData[2] and CurrentData[2][uidStr])

		local finalStats = nil
		if CurrentView == "1 Tempo" then
			finalStats = s1
		elseif CurrentView == "2 Tempo" then
			finalStats = s2
		else
			if s1 and s2 then
				finalStats = StatUtils.MergeStats(s1, s2)
			else
				finalStats = s1 or s2
			end
		end

		if finalStats then
			local copy = {}
			for k,v in pairs(finalStats) do copy[k] = v end
			finalStats = copy

			local p = Players:GetPlayerByUserId(tonumber(uidStr))
			StatUtils.CalculateDerivedStats(finalStats, p)

			table.insert(displayData, {
				UserId = uidStr,
				Name = p and p.Name or finalStats.Name or ("Player_"..uidStr),
				Stats = finalStats,
				PlayerObj = p
			})
		end
	end

	-- Sorting Logic
	table.sort(displayData, function(a, b)
		local valA = a.Stats[CurrentSortColumn] or 0
		local valB = b.Stats[CurrentSortColumn] or 0

		if CurrentSortColumn == "Player" then
			valA = a.Name:lower()
			valB = b.Name:lower()
		elseif CurrentSortColumn == "Passes" then
			valA = a.Stats.PassesCompleted or 0
			valB = b.Stats.PassesCompleted or 0
		end

		if SortDescending then
			return valA > valB
		else
			return valA < valB
		end
	end)

	for i = 1, math.max(#displayData, #RowPool) do
		local row = getOrCreateRow(i)
		local data = displayData[i]

		if data then
			row.Visible = true
			row.BackgroundColor3 = (i % 2 == 0) and THEME.RowEven or THEME.RowOdd
			local stats = data.Stats

			for _, col in ipairs(COLUMNS) do
				local cell = row:FindFirstChild(col.Id)
				if not cell then continue end

				if col.Id == "Player" then
					local dispName = data.Name

					-- Raposa: Adicionar emoji de dispositivo
					local deviceEmoji = ""
					if data.PlayerObj then
						local ls = data.PlayerObj:FindFirstChild("leaderstats")
						if ls and ls:FindFirstChild("Device") then
							deviceEmoji = ls.Device.Value .. " "
						end
					end

					if data.PlayerObj and StatUtils.IsGK(data.PlayerObj) then
						dispName = "ðŸ§¤ " .. dispName
					end
					cell.Text = deviceEmoji .. dispName
					cell.TextColor3 = data.PlayerObj and nameColorForPlayer(data.PlayerObj) or COLORS.Offline
				elseif col.Format == "CompAtt" then
					cell.Text = (stats.PassesCompleted or 0) .. "/" .. (stats.PassesAttempted or 0)
				elseif col.Format == "Percent" then
					cell.Text = formatPercent(stats[col.Id])
				elseif col.Format == "FloatShort" then
					cell.Text = string.format("%.0fs", stats[col.Id] or 0)
				else
					cell.Text = formatNumber(stats[col.Id])
				end
			end
		else
			row.Visible = false
		end
	end

	ContentFrame.CanvasSize = UDim2.new(0, 0, 0, #displayData * (isMobile and 24 or 34))
end

local function toggleStats(state)
	if not GuiInstance then createUI() end

	if state == nil then state = not GuiInstance.Enabled end

	GuiInstance.Enabled = state

	-- Esconde o inventário/ferramentas no mobile para não atrapalhar
	pcall(function()
		game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, not state)
	end)

	if state then
		BlurEffect.Enabled = true
		TweenService:Create(BlurEffect, TweenInfo.new(0.3), {Size = 15}):Play()
		updateView()
	else
		local t = TweenService:Create(BlurEffect, TweenInfo.new(0.2), {Size = 0})
		t:Play()
		t.Completed:Connect(function()
			if not GuiInstance.Enabled then
				BlurEffect.Enabled = false
			end
		end)
	end
end

--// UI Creation //--

createUI = function()
	if GuiInstance then GuiInstance:Destroy() end

	-- Setup Blur
	BlurEffect = Lighting:FindFirstChild("StatsBlur")
	if not BlurEffect then
		BlurEffect = Instance.new("BlurEffect")
		BlurEffect.Name = "StatsBlur"
		BlurEffect.Size = 0
		BlurEffect.Enabled = false
		BlurEffect.Parent = Lighting
	end

	local sg = Instance.new("ScreenGui")
	sg.Name = "StatsGui"
	sg.ResetOnSpawn = false
	sg.Enabled = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"

	if isMobile then
		mainFrame.Size = UDim2.new(0.98, 0, 0.85, 0)
		mainFrame.Position = UDim2.new(0.5, 0, 0.55, 0)
		mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	else
		mainFrame.Size = UDim2.new(0, 950, 0, 520)
		mainFrame.Position = UDim2.new(0.5, -475, 0.5, -260)
	end

	mainFrame.BackgroundColor3 = THEME.Background; mainFrame.BackgroundTransparency = 0.05
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = sg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = mainFrame

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = THEME.Border
	stroke.Parent = mainFrame

	-- Top Bar
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, 0, 0, isMobile and 36 or 50)
	topBar.BackgroundColor3 = THEME.Header
	topBar.BorderSizePixel = 0
	topBar.ZIndex = 2
	topBar.Parent = mainFrame

	local topCorner = Instance.new("UICorner")
	topCorner.CornerRadius = UDim.new(0, 10)
	topCorner.Parent = topBar; local headGrad = Instance.new("UIGradient"); headGrad.Rotation = 90; headGrad.Color = ColorSequence.new(Color3.fromRGB(255,255,255), Color3.fromRGB(200,200,200)); headGrad.Parent = topBar

	local tabContainer = Instance.new("Frame")
	tabContainer.Name = "Tabs"
	tabContainer.Size = isMobile and UDim2.new(0.85, -50, 1, 0) or UDim2.new(0.6, 0, 1, 0)
	tabContainer.Position = UDim2.new(0, 15, 0, 0)
	tabContainer.BackgroundTransparency = 1
	tabContainer.Parent = topBar

	local layoutTabs = Instance.new("UIListLayout")
	layoutTabs.FillDirection = Enum.FillDirection.Horizontal
	layoutTabs.Padding = UDim.new(0, 8)
	layoutTabs.VerticalAlignment = Enum.VerticalAlignment.Center
	layoutTabs.Parent = tabContainer

	local function createTab(name)
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.Text = name:upper()
		btn.Size = isMobile and UDim2.new(0, 90, 0, 30) or UDim2.new(0, 110, 0, 34)
		btn.BackgroundColor3 = THEME.UnselectedTab
		btn.TextColor3 = THEME.TextDim
		btn.Font = FONTS.Bold
		btn.TextSize = isMobile and 11 or 13
		btn.AutoButtonColor = true

		local uic = Instance.new("UICorner")
		uic.CornerRadius = UDim.new(0, 6)
		uic.Parent = btn

		btn.MouseButton1Click:Connect(function()
			CurrentView = name
			updateView()
			for _, child in ipairs(tabContainer:GetChildren()) do
				if child:IsA("TextButton") then
					local selected = (child.Name == name)
					child.BackgroundColor3 = selected and THEME.SelectedTab or THEME.UnselectedTab
					child.TextColor3 = selected and THEME.Text or THEME.TextDim
				end
			end
		end)

		btn.Parent = tabContainer
		return btn
	end

	createTab("1 Tempo")
	createTab("2 Tempo")
	local tabTotal = createTab("Total")
	tabTotal.BackgroundColor3 = THEME.SelectedTab
	tabTotal.TextColor3 = THEME.Text

	local closeBtn = Instance.new("TextButton")
	closeBtn.Text = "X"
	closeBtn.Size = isMobile and UDim2.new(0, 26, 0, 26) or UDim2.new(0, 32, 0, 32)
	closeBtn.Position = isMobile and UDim2.new(1, -34, 0.5, -13) or UDim2.new(1, -41, 0.5, -16)
	closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
	closeBtn.TextColor3 = THEME.Text
	closeBtn.Font = FONTS.Bold
	closeBtn.TextSize = isMobile and 14 or 18
	closeBtn.Parent = topBar

	Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

	closeBtn.MouseButton1Click:Connect(function()
		toggleStats(false)
	end)

	-- Horizontal Scroll Container for the table
	local tableScroller = Instance.new("ScrollingFrame")
	tableScroller.Name = "TableScroller"
	tableScroller.Size = UDim2.new(1, 0, 1, isMobile and -36 or -50)
	tableScroller.Position = UDim2.new(0, 0, 0, isMobile and 36 or 50)
	tableScroller.BackgroundTransparency = 1
	tableScroller.BorderSizePixel = 0
	tableScroller.ScrollBarThickness = isMobile and 2 or 0
	tableScroller.ScrollBarImageColor3 = THEME.Accent
	tableScroller.CanvasSize = UDim2.new(isMobile and 0, isMobile and 850 or 0, 0, 0)
	tableScroller.ClipsDescendants = true
	tableScroller.Parent = mainFrame

	-- Multi-level Table Header
	local tableHeader = Instance.new("Frame")
	tableHeader.Name = "TableHeader"
	tableHeader.Size = UDim2.new(isMobile and 0 or 1, isMobile and 850 or 0, 0, isMobile and 36 or 50)
	tableHeader.Position = UDim2.new(0, 0, 0, 0)
	tableHeader.BackgroundColor3 = THEME.Header
	tableHeader.BorderSizePixel = 0
	tableHeader.Parent = tableScroller

	-- Category Labels
	local categoryFrame = Instance.new("Frame")
	categoryFrame.Size = UDim2.new(1, 0, 0, isMobile and 14 or 20)
	categoryFrame.BackgroundTransparency = 1
	categoryFrame.Parent = tableHeader

	local currentX = 0
	local lastCategory = nil
	local categoryWidth = 0
	local startX = 0

	-- Create Category Labels logic
	for i, col in ipairs(COLUMNS) do
		if col.Category ~= lastCategory then
			if lastCategory and lastCategory ~= "" then
				local catLabel = Instance.new("TextLabel")
				catLabel.Text = lastCategory
				catLabel.Size = UDim2.new(categoryWidth, -6, 0, isMobile and 12 or 16)
				catLabel.Position = UDim2.new(startX, 3, 0, isMobile and 2 or 4)
				catLabel.BackgroundColor3 = COLUMNS[i-1].Color
				catLabel.BackgroundTransparency = 0.85
				catLabel.TextColor3 = COLUMNS[i-1].Color
				catLabel.Font = FONTS.Bold
				catLabel.TextSize = isMobile and 9 or 10
				catLabel.Parent = categoryFrame

				local uc = Instance.new("UICorner")
				uc.CornerRadius = UDim.new(0, 4)
				uc.Parent = catLabel
			end
			lastCategory = col.Category
			startX = currentX
			categoryWidth = 0
		end
		categoryWidth = categoryWidth + col.Width
		currentX = currentX + col.Width

		-- Edge case: Last column
		if i == #COLUMNS and lastCategory ~= "" then
			local catLabel = Instance.new("TextLabel")
			catLabel.Text = lastCategory
			catLabel.Size = UDim2.new(categoryWidth, -6, 0, isMobile and 12 or 16)
			catLabel.Position = UDim2.new(startX, 3, 0, isMobile and 2 or 4)
			catLabel.BackgroundColor3 = col.Color
			catLabel.BackgroundTransparency = 0.85
			catLabel.TextColor3 = col.Color
			catLabel.Font = FONTS.Bold
			catLabel.TextSize = isMobile and 9 or 10
			catLabel.Parent = categoryFrame

			local uc = Instance.new("UICorner")
			uc.CornerRadius = UDim.new(0, 4)
			uc.Parent = catLabel
		end
	end

	-- Sub-headers (Stat Names)
	currentX = 0
	for i, col in ipairs(COLUMNS) do
		local btn = Instance.new("TextButton")
		btn.Name = col.Id
		btn.Text = col.Name
		btn.Size = UDim2.new(col.Width, 0, 0, isMobile and 18 or 30)
		btn.Position = UDim2.new(currentX, 0, 0, isMobile and 16 or 20)
		btn.BackgroundTransparency = 1
		btn.TextColor3 = col.Color
		btn.Font = FONTS.Bold
		btn.TextSize = isMobile and 10 or 14
		btn.Parent = tableHeader

		btn.MouseButton1Click:Connect(function()
			if CurrentSortColumn == col.Id then
				SortDescending = not SortDescending
			else
				CurrentSortColumn = col.Id
				SortDescending = true
			end
			updateView()
		end)

		if col.Id == "Player" then
			btn.TextXAlignment = Enum.TextXAlignment.Left
			local padding = Instance.new("UIPadding")
			padding.PaddingLeft = UDim.new(0, isMobile and 8 or 15)
			padding.Parent = btn
		end

		-- Vertical Divider for Header
		if i < #COLUMNS then
			local divider = Instance.new("Frame")
			divider.Name = "Divider"
			divider.Size = UDim2.new(0, 1, 0.4, 0)
			divider.Position = UDim2.new(1, 0, 0.3, 0)
			divider.BackgroundColor3 = THEME.Border
			divider.BackgroundTransparency = 0.5
			divider.BorderSizePixel = 0
			divider.Parent = btn
		end

		currentX = currentX + col.Width
	end

	local headerLine = Instance.new("Frame")
	headerLine.Name = "HeaderLine"
	headerLine.Size = UDim2.new(1, 0, 0, 1)
	headerLine.Position = UDim2.new(0, 0, 1, -1)
	headerLine.BackgroundColor3 = THEME.Accent
	headerLine.BackgroundTransparency = 0.5
	headerLine.BorderSizePixel = 0
	headerLine.Parent = tableHeader

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "List"
	scroll.Size = UDim2.new(isMobile and 0 or 1, isMobile and 850 or 0, 1, isMobile and -36 or -50)
	scroll.Position = UDim2.new(0, 0, 0, isMobile and 36 or 50)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = isMobile and 0 or 5
	scroll.ScrollBarImageColor3 = THEME.Accent
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.Parent = tableScroller

	Instance.new("UIListLayout", scroll).SortOrder = Enum.SortOrder.LayoutOrder

	ContentFrame = scroll
	GuiInstance = sg
	RowPool = {}
	sg.Parent = PlayerGui
end



local function onStatsUpdate(action, statsData)
	if action == "Reset" then
		CurrentData = { [1] = {}, [2] = {} }
	elseif action == "Update" then
		CurrentData = statsData or {}
	elseif type(action) == "table" then
		CurrentData = action
	end

	if not GuiInstance then createUI() end
	updateView()
end

-- F4 Hotkey to toggle Stats

-- Hotkeys and External Toggles
local toggleEvent = ReplicatedStorage:FindFirstChild("ToggleStatsUI")
if not toggleEvent then
	toggleEvent = Instance.new("BindableEvent")
	toggleEvent.Name = "ToggleStatsUI"
	toggleEvent.Parent = ReplicatedStorage
end

local lastToggle = 0
toggleEvent.Event:Connect(function()
	local now = tick()
	if now - lastToggle < 0.2 then return end
	lastToggle = now
	toggleStats()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.F4 then
		toggleStats()
	end
end)

local networkFolder = ReplicatedStorage:WaitForChild("Network", 30)
if networkFolder then
	local event = networkFolder:WaitForChild("StatsUpdate", 30)
	if event then
		event.OnClientEvent:Connect(onStatsUpdate)
	end
end









