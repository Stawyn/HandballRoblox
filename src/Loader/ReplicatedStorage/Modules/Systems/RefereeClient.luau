--[[
    ================================================================================
    MÓDULO: RefereeClient
    ================================================================================
    Descrição: Interface do árbitro no cliente - UI e controles de partida.
               Gerencia botões de gol, timer, placar e comandos de árbitro.
    
    Funcionalidades:
        - Adicionar/remover gols (Home/Away)
        - Alterar nomes dos times
        - Controlar timer (iniciar, pausar, resetar)
        - Toggle ball timer
        - Confirmação de reset de partida
        - Sincronização com servidor
    
    UI Elements:
        - MainFrame: Container principal
        - HomeFrame/AwayFrame: Controles por time
        - TimerPanel: Controles de cronômetro
        - ResetConfirmation: Diálogo de confirmação
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: SERVIÇOS E DEPENDÊNCIAS
--// ============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientNetwork = require("../Implementation/ClientNetwork")
local RefereeEvent = ClientNetwork.RefereeEvent
local RefereeEventRemote = ClientNetwork.RefereeEventRemote

--// ============================================================================
--// SETOR: REFERÊNCIAS
--// ============================================================================

local localPlayer = Players.LocalPlayer :: Player

-- Data Values
local data = workspace:WaitForChild("Core"):WaitForChild("Data") :: Folder
local awayName = data:WaitForChild("AwayName") :: StringValue
local homeName = data:WaitForChild("HomeName") :: StringValue
local ballTimer = data:WaitForChild("BallTimer") :: BoolValue
local matchPaused = data:WaitForChild("MatchPaused") :: BoolValue
local homeScoreNumberValue = data:WaitForChild("HomeScore") :: NumberValue
local awayScoreNumberValue = data:WaitForChild("AwayScore") :: NumberValue
local HALF = data:WaitForChild("Half") :: NumberValue

-- UI References
local playerGui = localPlayer.PlayerGui
local refereeUI = playerGui:WaitForChild("RefereeUI", math.huge)
local refFrame = refereeUI:WaitForChild("MainFrame")
local awayFrame = refFrame:WaitForChild("AwayFrame")
local homeFrame = refFrame:WaitForChild("HomeFrame")

-- Home Team UI
local homeAddGoal = homeFrame:WaitForChild("AddGoal") :: ImageButton
local homeRemoveGoal = homeFrame:WaitForChild("RemoveGoal") :: ImageButton
local homeTeamName = homeFrame:WaitForChild("NameTextBox") :: TextBox
local homeScore = homeFrame:WaitForChild("Score") :: TextLabel

-- Away Team UI
local awayAddGoal = awayFrame:WaitForChild("AddGoal") :: ImageButton
local awayRemoveGoal = awayFrame:WaitForChild("RemoveGoal") :: ImageButton
local awayTeamName = awayFrame:WaitForChild("NameTextBox") :: TextBox
local awayScore = awayFrame:WaitForChild("Score") :: TextLabel

-- Timer UI
local timerFrame = refFrame:WaitForChild("TimerPanel"):WaitForChild("TimerFrame") :: Frame
local ballTimerStatus = refFrame:WaitForChild("TimerPanel"):WaitForChild("BallTimer"):WaitForChild("BallTimerStatus") :: ImageButton
local pause = timerFrame:WaitForChild("Pause") :: ImageButton
local reset = timerFrame:WaitForChild("Reset") :: ImageButton
local resume = timerFrame:WaitForChild("Resume") :: ImageButton

-- Network
local NETWORK_FOLDER = ReplicatedStorage:WaitForChild("Network") :: Folder
local STATS_EVENT = NETWORK_FOLDER:WaitForChild("StatsUpdate") :: RemoteEvent

--// ============================================================================
--// SETOR: CONSTANTES DE ÍCONES
--// ============================================================================

local DEACTIVATED_BALL_TIMER = {
	Image = "rbxassetid://8445519745",
	ImageRectOffset = Vector2.new(940, 784),
	ImageRectSize = Vector2.new(48, 48),
}

local ACTIVATED_BALL_TIMER = {
	Image = "rbxassetid://8445519745",
	ImageRectOffset = Vector2.new(4, 836),
	ImageRectSize = Vector2.new(48, 48),
}

--// ============================================================================
--// SETOR: UI DE CONFIRMAÇÃO
--// ============================================================================

local confirmationFrame = Instance.new("Frame")
confirmationFrame.Name = "ResetConfirmation"
confirmationFrame.Size = UDim2.new(0, 320, 0, 160)
confirmationFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
confirmationFrame.AnchorPoint = Vector2.new(0.5, 0.5)
confirmationFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
confirmationFrame.BorderSizePixel = 2
confirmationFrame.BorderColor3 = Color3.fromRGB(255, 255, 255)
confirmationFrame.Visible = false
confirmationFrame.ZIndex = 999
confirmationFrame.Parent = refereeUI

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = confirmationFrame

local confirmText = Instance.new("TextLabel")
confirmText.Size = UDim2.new(1, -40, 0, 70)
confirmText.Position = UDim2.new(0, 20, 0, 10)
confirmText.Text = "Deseja resetar o jogo?\nIsso irá limpar todas as estatísticas e placar."
confirmText.TextColor3 = Color3.new(1, 1, 1)
confirmText.TextWrapped = true
confirmText.BackgroundTransparency = 1
confirmText.Font = Enum.Font.SourceSansBold
confirmText.TextSize = 20
confirmText.ZIndex = 1000
confirmText.Parent = confirmationFrame

local yesButton = Instance.new("TextButton")
yesButton.Size = UDim2.new(0, 110, 0, 45)
yesButton.Position = UDim2.new(0.25, -55, 0.75, -22)
yesButton.Text = "SIM"
yesButton.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
yesButton.TextColor3 = Color3.new(1, 1, 1)
yesButton.Font = Enum.Font.SourceSansBold
yesButton.TextSize = 22
yesButton.ZIndex = 1000
yesButton.Parent = confirmationFrame
Instance.new("UICorner", yesButton).CornerRadius = UDim.new(0, 6)

local noButton = Instance.new("TextButton")
noButton.Size = UDim2.new(0, 110, 0, 45)
noButton.Position = UDim2.new(0.75, -55, 0.75, -22)
noButton.Text = "NÃO"
noButton.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
noButton.TextColor3 = Color3.new(1, 1, 1)
noButton.Font = Enum.Font.SourceSansBold
noButton.TextSize = 22
noButton.ZIndex = 1000
noButton.Parent = confirmationFrame
Instance.new("UICorner", noButton).CornerRadius = UDim.new(0, 6)

--// ============================================================================
--// SETOR: FUNÇÕES AUXILIARES
--// ============================================================================

--- Mostra diálogo de confirmação de reset
local function showResetConfirmation()
	confirmationFrame.Visible = true
	confirmationFrame:TweenPosition(UDim2.new(0.5, 0, 0.5, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.3, true)
end

--- Atualiza ícone do ball timer
local function onBallTimerUpdateStatus()
	local iconData = if ballTimer.Value then ACTIVATED_BALL_TIMER else DEACTIVATED_BALL_TIMER
	ballTimerStatus.Image = iconData.Image
	ballTimerStatus.ImageRectOffset = iconData.ImageRectOffset
	ballTimerStatus.ImageRectSize = iconData.ImageRectSize
end

--- Atualiza placar na UI
local function onScoreUpdate()
	homeScore.Text = tostring(homeScoreNumberValue.Value)
	awayScore.Text = tostring(awayScoreNumberValue.Value)
end

--- Atualiza estado de pausa na UI
local function onMatchPausedUpdate()
	if matchPaused.Value then
		pause.Visible = false
		resume.Visible = true
		timerFrame.BackgroundTransparency = 0.5
	else
		if HALF.Value > 0 then
			pause.Visible = true
			resume.Visible = false
		else
			pause.Visible = false
			resume.Visible = true
		end
		timerFrame.BackgroundTransparency = 0
	end
end

--// ============================================================================
--// SETOR: CONEXÕES - CONFIRMAÇÃO
--// ============================================================================

yesButton.MouseButton1Click:Connect(function()
	RefereeEvent:ResetMatch()
	confirmationFrame.Visible = false
end)

noButton.MouseButton1Click:Connect(function()
	confirmationFrame.Visible = false
end)

-- Handle server-side confirmation requests
RefereeEventRemote.OnClientEvent:Connect(function(eventData)
	if eventData and eventData.action == "SHOW_CONFIRM_RESET" then
		showResetConfirmation()
	end
end)

--// ============================================================================
--// SETOR: CONEXÕES - GOLS
--// ============================================================================

homeAddGoal.MouseButton1Click:Connect(function()
	RefereeEvent:AddGoal(true)
end)

awayAddGoal.MouseButton1Click:Connect(function()
	RefereeEvent:AddGoal(false)
end)

homeRemoveGoal.MouseButton1Click:Connect(function()
	RefereeEvent:RemoveGoal(true)
end)

awayRemoveGoal.MouseButton1Click:Connect(function()
	RefereeEvent:RemoveGoal(false)
end)

--// ============================================================================
--// SETOR: CONEXÕES - NOMES DE TIMES
--// ============================================================================

homeTeamName.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		RefereeEvent:ChangeTeamName(homeTeamName.Text, true)
	end
end)

awayTeamName.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		RefereeEvent:ChangeTeamName(awayTeamName.Text, false)
	end
end)

--// ============================================================================
--// SETOR: CONEXÕES - TIMER
--// ============================================================================

pause.MouseButton1Click:Connect(function()
	RefereeEvent:PauseMatch()
end)

resume.MouseButton1Click:Connect(function()
	if matchPaused.Value then
		RefereeEvent:ResumeMatch()
	else
		RefereeEvent:BeginLeague()
	end
end)

reset.MouseButton1Click:Connect(function()
	showResetConfirmation()
end)

ballTimerStatus.MouseButton1Click:Connect(function()
	RefereeEvent:ToggleBallTimer()
end)

--// ============================================================================
--// SETOR: SINCRONIZAÇÃO COM SERVIDOR
--// ============================================================================

ballTimer:GetPropertyChangedSignal("Value"):Connect(onBallTimerUpdateStatus)
homeScoreNumberValue:GetPropertyChangedSignal("Value"):Connect(onScoreUpdate)
awayScoreNumberValue:GetPropertyChangedSignal("Value"):Connect(onScoreUpdate)
matchPaused:GetPropertyChangedSignal("Value"):Connect(onMatchPausedUpdate)
HALF:GetPropertyChangedSignal("Value"):Connect(onMatchPausedUpdate)

-- Inicialização
onBallTimerUpdateStatus()
onScoreUpdate()
onMatchPausedUpdate()

-- Sync com reset de estatísticas
STATS_EVENT.OnClientEvent:Connect(function(action, ...)
	if action == "Reset" then
		onScoreUpdate()
		onBallTimerUpdateStatus()
		if matchPaused.Value then
			onMatchPausedUpdate()
		end
	end
end)

return {}
