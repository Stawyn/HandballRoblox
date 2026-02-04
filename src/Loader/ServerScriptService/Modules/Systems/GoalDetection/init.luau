--[[
    ================================================================================
    MODULO: GoalDetection
    ================================================================================
    Descricao: Sistema de deteccao de gols (GLT - Goal Line Technology).
               Detecta quando a bola cruza a linha do gol e registra estatisticas.
    
    Funcionalidades:
        - Deteccao de gol via GLT (Goal Line Technology)
        - Prevencao de gols contra (own goals)
        - Registro de gols, assistencias e fast breaks
        - Emoji de celebracao acima da cabeca do marcador
        - Registro de gols sofridos para goleiros
    
    Dependencias:
        - ABHBall: Manipulacao da bola
        - GameStatistics: Registro de eventos
        - ABHLeague: Controle de partida
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: SERVICOS
--// ============================================================================

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

--// ============================================================================
--// SETOR: DEPENDENCIAS
--// ============================================================================

local Maid = require("../../../ReplicatedStorage/Utilities/Maid")
local SharedTypes = require("../../../ReplicatedStorage/Utilities/SharedTypes")
local Vector = require("../../../ReplicatedStorage/Utilities/Vector")
local ABHBallModule = require("./ABHBAll")
local GameStatistics = require("./GameStatistics")
local ABHLeague = require("../Implementation/ABHLeague")

--// ============================================================================
--// SETOR: CONSTANTES
--// ============================================================================

local BALLS_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Balls") :: Folder
local DATA_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Data") :: Folder
local GLT_FOLDER = workspace:WaitForChild("Core"):WaitForChild("GLT") :: Folder
local HOME_GLT = GLT_FOLDER:WaitForChild("Home") :: BasePart
local AWAY_GLT = GLT_FOLDER:WaitForChild("Away") :: BasePart

local GLT_DELAY = 0.275 -- Delay antes de confirmar gol (para saves)

--// ============================================================================
--// SETOR: FUNCOES INTERNAS - VISUAL
--// ============================================================================

--- Mostra emoji de gol acima da cabeca do jogador
-- @param player Player - O jogador que marcou
local function showGoalEmoji(player: Player)
	local character = player.Character
	if not character then return end
	local head = character:FindFirstChild("Head")
	if not head then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "GoalEmoji"
	billboard.Size = UDim2.new(2.5, 0, 2.5, 0)
	billboard.Adornee = head
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = true

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(0, 0, 0, 0) -- Inicia pequeno
	label.Position = UDim2.new(0.5, 0, 0.5, 0)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Text = "⚽"
	label.TextScaled = true
	label.Parent = billboard

	billboard.Parent = head

	-- Tween para aparecer e crescer
	local showTween = TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(1, 0, 1, 0)
	})
	showTween:Play()

	-- Flutuar para cima gradualmente
	local floatTween = TweenService:Create(billboard, TweenInfo.new(5, Enum.EasingStyle.Linear), {
		StudsOffset = Vector3.new(0, 4.5, 0)
	})
	floatTween:Play()

	-- Sumir apos 4 segundos
	task.delay(4, function()
		if not label or not billboard then return end
		local fadeTween = TweenService:Create(label, TweenInfo.new(1), {
			TextTransparency = 1
		})
		fadeTween:Play()
		fadeTween.Completed:Connect(function()
			billboard:Destroy()
		end)
	end)
end

--// ============================================================================
--// SETOR: FUNCOES INTERNAS - LOGICA DE GOL
--// ============================================================================

--- Processa deteccao de gol para um GLT
-- @param GLT BasePart - A parte do GLT (Home ou Away)
local function handleGLT(GLT: BasePart)
	local mainConnection = Maid.new()
	local savedConnection = Maid.new()

	local function CleanConnections()
		mainConnection:DoCleaning()
		savedConnection:DoCleaning()
	end

	local function CreateGLTConnections()
		CleanConnections()

		local saved = false
		mainConnection:GiveTask(GLT.Touched:Connect(function(otherPart)
			if not otherPart:IsDescendantOf(BALLS_FOLDER) then
				return
			end

			local ABHBall = otherPart :: SharedTypes.ABHBallInstance
			local currentPlayer = ABHBall.Information.CurrentPlayerOnBall
			if currentPlayer.Value then
				return
			end

			local velocityVector = Vector:Vector3ToVectorLib(ABHBall.AssemblyLinearVelocity)
			local velocity = vector.magnitude(velocityVector)

			savedConnection:GiveTask(currentPlayer:GetPropertyChangedSignal("Value"):Connect(function()
				saved = true
				CreateGLTConnections()
				return
			end))

			task.wait(GLT_DELAY)
			if saved then 
				return
			end
			if currentPlayer.Value then
				return
			end
			if not ABHBall:IsDescendantOf(BALLS_FOLDER) then
				return
			end
			if ABHBallModule:GetGLTCooldown(ABHBall) then
				return
			end
			ABHBallModule:SetGLTCooldown(ABHBall, true)

			local scorer = ABHBall.Information.LastThrow.Value :: Player?
			local previousThrower = ABHBall.Information.LastLastThrow.Value :: Player?
			
			if scorer then
				-- Prevencao de gol contra
				local scorerTeamName = (scorer.Team and scorer.Team.Name) or ""
				local gltName = GLT.Name
				if (scorerTeamName:find("Home") and gltName == "Home") or (scorerTeamName:find("Away") and gltName == "Away") then
					print("[GoalDetection] Own goal prevented for "..scorer.Name.." into "..gltName.." GLT")
					ABHBall.CanTouch = false
					ABHBall.Anchored = true
					if ABHBall:FindFirstChild("Timer") then ABHBall.Timer:Destroy() end
					if ABHBall:FindFirstChild("SpecialMesh") then ABHBall.SpecialMesh:Destroy() end
					ABHBall.TextureID = ""
					ABHBall.Color = BrickColor.Green().Color
					ABHBall.Material = Enum.Material.Neon
					ABHBall.Transparency = 0
					Debris:AddItem(ABHBall, 3)
					CreateGLTConnections()
					return
				end
				
				-- Verificacao de Fast Break (GK inimigo -> Scorer -> Gol)
				local isFastBreak = false
				if previousThrower then
					local scorerTeam = scorer.Team
					local prevTeam = previousThrower.Team

					local isEnemyGK = false
					if scorerTeam.Name:find("Home") then
						if prevTeam.Name == "-Away Goalkeeper" then isEnemyGK = true end
					elseif scorerTeam.Name:find("Away") then
						if prevTeam.Name == "-Home Goalkeeper" then isEnemyGK = true end
					end

					if isEnemyGK then
						isFastBreak = true
					end
				end

				-- Registro de gol/fast break
				if isFastBreak then
					GameStatistics.RecordEvent(scorer, "FastBreak")
					showGoalEmoji(scorer)
				else
					GameStatistics.RecordEvent(scorer, "Goal")
					showGoalEmoji(scorer)
					GameStatistics.RecordEvent(scorer, "SOG")
				end

				-- Assistencia (mesmo time, nao fast break)
				if previousThrower and previousThrower ~= scorer and not isFastBreak then
					local scorerTeam = scorer.Team
					local prevTeam = previousThrower.Team

					local sSide = if scorerTeam.Name:find("Home") then "Home" else "Away"
					local pSide = if prevTeam.Name:find("Home") then "Home" else "Away"

					if sSide == pSide then
						GameStatistics.RecordEvent(previousThrower, "Assist")
						if prevTeam.Name:find("Goalkeeper") then
							GameStatistics.RecordEvent(previousThrower, "GKAssist")
						end
					end
				end
				
				-- Gol sofrido para goleiro adversario
				local scoringTeam = scorer.Team
				local defendingGKTeam = nil
				if scoringTeam.Name == "Home Team" then
					defendingGKTeam = Teams:FindFirstChild("-Away Goalkeeper")
				elseif scoringTeam.Name == "Away Team" then
					defendingGKTeam = Teams:FindFirstChild("-Home Goalkeeper")
				end

				if defendingGKTeam then
					for _, gk in pairs(defendingGKTeam:GetPlayers()) do
						GameStatistics.RecordEvent(gk, "GoalConceded")
					end
				end
			end

			-- Destruir bola com efeito visual
			ABHBall.CanTouch = false
			ABHBall.Anchored = true
			CleanConnections()
			ABHBall.Timer:Destroy()
			ABHBall.SpecialMesh:Destroy()
			ABHBall.TextureID = ""
			ABHBall.Color = BrickColor.Green().Color
			ABHBall.Material = Enum.Material.Neon
			ABHBall.Transparency = 0
			Debris:AddItem(ABHBall, 3)

			-- Atualizar placar
			local oppositeName = if GLT.Name == "Home" then "Away" else "Home"
			local scoreNumberValue = DATA_FOLDER:FindFirstChild(("%sScore"):format(oppositeName)) :: NumberValue
			scoreNumberValue.Value += 1

			task.delay(2, function()
				ABHLeague:GoalScored(oppositeName)
			end)

			CreateGLTConnections()
		end))
	end

	CreateGLTConnections()
end

--// ============================================================================
--// SETOR: INICIALIZACAO
--// ============================================================================

task.spawn(handleGLT, HOME_GLT)
task.spawn(handleGLT, AWAY_GLT)

return {}
