--[[
    ================================================================================
    MÓDULO: ScoreboardClient
    ================================================================================
    Descrição: Placar visual do jogo - mostra score, timer, nomes e estado.
               Suporta arrastar para reposicionar.
    
    Funcionalidades:
        - Exibição de placar (Home x Away)
        - Timer formatado (MM:SS)
        - Nomes dos times
        - Indicador de tempo extra (ET) / Último ataque (LA)
        - Estado da partida (1T, 2T, Pausado)
        - Drag para reposicionar
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: SERVIÇOS E DEPENDÊNCIAS
--// ============================================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// ============================================================================
--// SETOR: REFERÊNCIAS
--// ============================================================================

local DATA = workspace:WaitForChild("Core"):WaitForChild("Data")
local NETWORK_FOLDER = ReplicatedStorage:WaitForChild("Network") :: Folder
local STATS_EVENT = NETWORK_FOLDER:WaitForChild("StatsUpdate") :: RemoteEvent

-- Values para estado da partida
local HALF = DATA:FindFirstChild("Half")
local MATCH_PAUSED = DATA:FindFirstChild("MatchPaused")

local localPlayer = Players.LocalPlayer :: Player
local playerGui = localPlayer.PlayerGui
local scoreboardUI = playerGui:WaitForChild("Scoreboard", math.huge):WaitForChild("Scoreboard", math.huge)

--// ============================================================================
--// SETOR: CONSTANTES
--// ============================================================================

local ET_VISIBLE_POS = UDim2.new(1, 5, 0, 0)
local ET_INVIS_POS = UDim2.new(1, -35, 0, 0)

--// ============================================================================
--// SETOR: SISTEMA DE DRAG
--// ============================================================================

scoreboardUI.Active = true
scoreboardUI.Selectable = true

local dragToggle = false
local dragStart = nil
local startPos = nil

scoreboardUI.InputBegan:Connect(function(input)
	if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		dragToggle = true
		dragStart = input.Position
		startPos = scoreboardUI.Position
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		if dragToggle then
			local delta = input.Position - dragStart
			local position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
			TweenService:Create(scoreboardUI, TweenInfo.new(0.08, Enum.EasingStyle.Sine), {Position = position}):Play()
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		dragToggle = false
	end
end)

--// ============================================================================
--// SETOR: LABEL DE ESTADO DA PARTIDA
--// ============================================================================

local matchLabel = scoreboardUI:FindFirstChild("Match") or scoreboardUI:FindFirstChild("MatchText") or scoreboardUI:FindFirstChild("MatchLabel")
if not matchLabel then
	matchLabel = Instance.new("TextLabel")
	matchLabel.Name = "Match"
	matchLabel.Size = UDim2.new(0, 150, 0, 20)
	matchLabel.BackgroundTransparency = 1
	matchLabel.TextColor3 = Color3.fromRGB(255,255,255)
	matchLabel.Font = Enum.Font.GothamBold
	matchLabel.TextSize = 14
	matchLabel.Text = ""
	matchLabel.Position = UDim2.new(0.5, -75, 0, -25)
	matchLabel.Parent = scoreboardUI
end

--// ============================================================================
--// SETOR: FUNÇÕES DE UPDATE
--// ============================================================================

--- Atualiza label de estado da partida
local function updateMatchLabel()
	local status = ""
	local halfVal = HALF and HALF.Value or 0
	local paused = MATCH_PAUSED and MATCH_PAUSED.Value or false

	if paused then
		status = "ABH - Pausado"
	elseif halfVal == 1 then
		status = "ABH - 1T"
	elseif halfVal == 2 then
		status = "ABH - 2T"
	else
		status = "ABH"
	end

	matchLabel.Text = status
end

--- Atualiza nomes dos times
local function onNamesUpdate()
	local homeName = DATA.HomeName.Value
	local awayName = DATA.AwayName.Value

	scoreboardUI.HomeName.Text = homeName
	scoreboardUI.AwayName.Text = awayName
end

--- Atualiza placar
local function onScoreUpdated()
	local homeScore = DATA.HomeScore.Value
	local awayScore = DATA.AwayScore.Value

	scoreboardUI.Score.Text = string.format("%d - %d", homeScore, awayScore)
end

--- Atualiza timer
local function onTimerChanged()
	local currentSeconds = DATA.Timer.Value
	local minutes = math.floor(currentSeconds / 60)
	local seconds = currentSeconds % 60

	scoreboardUI.Timer.Text = string.format("%02d:%02d", minutes, seconds)
end

--- Atualiza indicador de tempo extra / último ataque
local function onETChanged()
	local isLA = DATA.LastAttack.Value
	local addedTime = DATA.AddedTime.Value / 60

	if isLA then
		scoreboardUI.ET.Text = "LA"
		TweenService:Create(scoreboardUI.ET, TweenInfo.new(.1), {
			Position = ET_VISIBLE_POS,
			BackgroundTransparency = 0,
			TextTransparency = 0
		}):Play()
	elseif not isLA and addedTime > 0 then
		scoreboardUI.ET.Text = "+"..tostring(addedTime)
		TweenService:Create(scoreboardUI.ET, TweenInfo.new(.1), {
			Position = ET_VISIBLE_POS,
			BackgroundTransparency = 0,
			TextTransparency = 0
		}):Play()
	else
		TweenService:Create(scoreboardUI.ET, TweenInfo.new(.1), {
			Position = ET_INVIS_POS,
			BackgroundTransparency = 1,
			TextTransparency = 1
		}):Play()
	end
end

--// ============================================================================
--// SETOR: CONEXÕES
--// ============================================================================

-- Estado da partida
if HALF then HALF:GetPropertyChangedSignal("Value"):Connect(updateMatchLabel) end
if MATCH_PAUSED then MATCH_PAUSED:GetPropertyChangedSignal("Value"):Connect(updateMatchLabel) end

-- Nomes
DATA.HomeName:GetPropertyChangedSignal("Value"):Connect(onNamesUpdate)
DATA.AwayName:GetPropertyChangedSignal("Value"):Connect(onNamesUpdate)

-- Placar
DATA.HomeScore:GetPropertyChangedSignal("Value"):Connect(onScoreUpdated)
DATA.AwayScore:GetPropertyChangedSignal("Value"):Connect(onScoreUpdated)

-- Timer
DATA.Timer:GetPropertyChangedSignal("Value"):Connect(onTimerChanged)

-- Tempo Extra
DATA.LastAttack:GetPropertyChangedSignal("Value"):Connect(onETChanged)
DATA.AddedTime:GetPropertyChangedSignal("Value"):Connect(onETChanged)

-- Reset de estatísticas
STATS_EVENT.OnClientEvent:Connect(function(action, ...)
	if action == "Reset" then
		matchLabel.Text = "ABH - Resetado"
	end
end)

--// ============================================================================
--// SETOR: INICIALIZAÇÃO
--// ============================================================================

updateMatchLabel()
onNamesUpdate()
onScoreUpdated()
onTimerChanged()
onETChanged()

return {}
