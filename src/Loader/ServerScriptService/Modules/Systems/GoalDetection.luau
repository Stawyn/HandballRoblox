--[[
	================================================================================
	MÓDULO: GoalDetection
	================================================================================
	
	Descrição:
		Sistema de detecção de gols e estatísticas do servidor.
		Gerencia a tecnologia da linha do gol (GLT) e atribui pontos/estatísticas.
	
	Funcionalidades:
		- Detecta quando a bola cruza a linha (GLT Hitbox).
		- Previne gols contra (bloqueia e reinicia a bola).
		- Registra estatísticas avançadas (Gol, Assistência, Contra-Ataque/FastBreak).
		- Exibe efeitos visuais (Emoji de Gol).
		- Controla o placar e reinício da rodada.
	
	Dependências:
		- Maid/SharedTypes/Vector (Utilitários)
		- ABHBAll (Lógica da Bola)
		- ABHLeague (Lógica da Liga)
		- GameStatistics (Estatísticas do Usuário)
	
	Autor: Sistema ABH (com modificações por Raposa)
	================================================================================
]]

--// ============================================================================
--// SETOR: Serviços
--// ============================================================================

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

--// ============================================================================
--// SETOR: Dependências
--// ============================================================================

local Maid = require(game:GetService("ReplicatedStorage"):WaitForChild("Utilities"):WaitForChild("Maid"))
local SharedTypes = require(game:GetService("ReplicatedStorage"):WaitForChild("Utilities"):WaitForChild("SharedTypes"))
local Vector = require(game:GetService("ReplicatedStorage"):WaitForChild("Utilities"):WaitForChild("Vector"))
local ABHBallModule = require("./ABHBAll")
local GameStatistics = require("./GameStatistics") -- Módulo de Estatísticas
local ABHLeague = require("../Implementation/ABHLeague")

--// ============================================================================
--// SETOR: Referências de Jogo
--// ============================================================================

local CORE_FOLDER = Workspace:WaitForChild("Core")
local BALLS_FOLDER = CORE_FOLDER:WaitForChild("Balls") :: Folder
local DATA_FOLDER = CORE_FOLDER:WaitForChild("Data") :: Folder
local GLT_FOLDER = CORE_FOLDER:WaitForChild("GLT") :: Folder

local HOME_GLT = GLT_FOLDER:WaitForChild("Home") :: BasePart
local AWAY_GLT = GLT_FOLDER:WaitForChild("Away") :: BasePart

--// ============================================================================
--// SETOR: Constantes
--// ============================================================================

local MAXIMUM_GLT_DELAY = 0.45
local MINIMUM_GLT_DELAY = 0.2
local ADDITIONAL_DELAY = 0.125
local GLT_DELAY = 0.3 -- Delay para confirmar gol

--// ============================================================================
--// SETOR: Funções Auxiliares (Visual)
--// ============================================================================

--[[
	Exibe um emoji de bola de futebol acima da cabeça do jogador que marcou.
	Cria um efeito visual flutuante.
	
	@param player Player - O jogador que marcou
]]
local function showGoalEmoji(player: Player)
	local character = player.Character
	if not character then return end
	local head = character:FindFirstChild("Head")
	if not head then return end

	-- Cria BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "GoalEmoji"
	billboard.Size = UDim2.new(2.5, 0, 2.5, 0)
	billboard.Adornee = head
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = true

	-- Cria Texto (Emoji)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(0, 0, 0, 0) -- Inicia pequeno para animar
	label.Position = UDim2.new(0.5, 0, 0.5, 0)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Text = "⚽"
	label.TextScaled = true
	label.Parent = billboard

	billboard.Parent = head

	-- Animação 1: Aparecer e Crescer (Pop-in)
	local showTween = TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(1, 0, 1, 0)
	})
	showTween:Play()

	-- Animação 2: Flutuar para cima
	local floatTween = TweenService:Create(billboard, TweenInfo.new(5, Enum.EasingStyle.Linear), {
		StudsOffset = Vector3.new(0, 4.5, 0)
	})
	floatTween:Play()

	-- Limpeza automática após 4 segundos
	task.delay(4, function()
		if not label or not billboard then return end

		-- Animação 3: Desaparecer (Fade-out)
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
--// SETOR: Lógica Principal (GLT Handler)
--// ============================================================================

--[[
	Gerencia a lógica de detecção de gol para uma trave (GLT) específica.
	
	@param GLT BasePart - A parte que representa a linha do gol (Hitbox)
]]
function handleGLT(GLT: BasePart)
	local mainConnection = Maid.new()
	local savedConnection = Maid.new()

	-- Helper para limpar conexões
	local function CleanConnections()
		mainConnection:DoCleaning()
		savedConnection:DoCleaning()
	end

	-- Função recursiva para recriar conexões
	local function CreateGLTConnections()
		CleanConnections()

		local saved = false

		-- Evento de Toque na Linha do Gol
		mainConnection:GiveTask(GLT.Touched:Connect(function(otherPart)
			-- Verifica se é uma bola válida
			if not otherPart:IsDescendantOf(BALLS_FOLDER) then
				return
			end

			local ABHBall = otherPart :: SharedTypes.ABHBallInstance
			local currentPlayer = ABHBall.Information.CurrentPlayerOnBall

			-- Se alguém está segurando a bola, não é gol
			if currentPlayer.Value then
				return
			end

			-- Lógica de defesa (Save)
			savedConnection:GiveTask(currentPlayer:GetPropertyChangedSignal("Value"):Connect(function()
				saved = true
				CreateGLTConnections() -- Bola foi pega, reinicia detecção
				return
			end))

			-- Aguarda delay de confirmação
			task.wait(GLT_DELAY)

			-- Validações pós-delay
			if saved then return end
			if currentPlayer.Value then return end
			if not ABHBall:IsDescendantOf(BALLS_FOLDER) then return end

			-- Verifica cooldown de gol na bola (evita duplo registro)
			if ABHBallModule:GetGLTCooldown(ABHBall) then
				return
			end
			ABHBallModule:SetGLTCooldown(ABHBall, true)

			-- ==========================================================================
			-- Lógica de Estatísticas e Regras (Raposa)
			-- ==========================================================================

			local scorer = ABHBall.Information.LastThrow.Value :: Player?
			local previousThrower = ABHBall.Information.LastLastThrow.Value :: Player? -- Quem jogou antes do scorer (Assistência)

			if scorer then
				local scorerTeamName = (scorer.Team and scorer.Team.Name) or ""
				local gltName = GLT.Name

				-- 1. Prevenção de Gol Contra
				local isOwnGoal = (scorerTeamName:find("Home") and gltName == "Home") or (scorerTeamName:find("Away") and gltName == "Away")

				if isOwnGoal then
					print("[GoalDetection] Own goal prevented for "..scorer.Name.." into "..gltName.." GLT")

					-- Reseta a bola como se fosse um toque não-pontuado
					ABHBall.CanTouch = false
					ABHBall.Anchored = true
					if ABHBall:FindFirstChild("Timer") then ABHBall.Timer:Destroy() end
					if ABHBall:FindFirstChild("SpecialMesh") then ABHBall.SpecialMesh:Destroy() end

					-- Restaura visual padrào
					ABHBall.TextureID = ""
					ABHBall.Color = BrickColor.Green().Color
					ABHBall.Material = Enum.Material.Neon
					ABHBall.Transparency = 0

					Debris:AddItem(ABHBall, 3)
					CreateGLTConnections()
					return -- Sai da função, não contabiliza gol
				end

				-- 2. Detecção de Fast Break (Contra-Ataque)
				-- Regra estrita: Goleiro Inimigo -> Atacante -> Gol
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

				-- 3. Registro do Evento de Gol
				if isFastBreak then
					GameStatistics.RecordEvent(scorer, "FastBreak")
					showGoalEmoji(scorer)
				else
					GameStatistics.RecordEvent(scorer, "Goal")
					showGoalEmoji(scorer)
					-- Conta também como chute a gol (SOG)
					GameStatistics.RecordEvent(scorer, "SOG")
				end

				-- 4. Registro de Assistência
				-- Regra estrita: Mesma equipe, não pode ser contra-ataque
				if previousThrower and previousThrower ~= scorer and not isFastBreak then
					local scorerTeam = scorer.Team
					local prevTeam = previousThrower.Team

					-- Normaliza nome do time (Ex: "Home Team" e "-Home Goalkeeper" são do mesmo lado "Home")
					local sSide = if scorerTeam.Name:find("Home") then "Home" else "Away"
					local pSide = if prevTeam.Name:find("Home") then "Home" else "Away"

					if sSide == pSide then
						GameStatistics.RecordEvent(previousThrower, "Assist")
						-- Assistência de Goleiro
						if prevTeam.Name:find("Goalkeeper") then
							GameStatistics.RecordEvent(previousThrower, "GKAssist")
						end
					end
				end

				-- 5. Registro de Gol Sofrido (para goleiro defensor)
				local defendingGKTeam = nil
				if scorer.Team.Name == "Home Team" then
					defendingGKTeam = Teams:FindFirstChild("-Away Goalkeeper")
				elseif scorer.Team.Name == "Away Team" then
					defendingGKTeam = Teams:FindFirstChild("-Home Goalkeeper")
				end

				if defendingGKTeam then
					for _, gk in pairs(defendingGKTeam:GetPlayers()) do
						GameStatistics.RecordEvent(gk, "GoalConceded")
					end
				end
			end

			-- ==========================================================================
			-- Finalização do Gol
			-- ==========================================================================

			-- Desativa a bola
			ABHBall.CanTouch = false
			ABHBall.Anchored = true
			CleanConnections()

			-- Limpa visuais da bola (Trail, Mesh, etc)
			if ABHBall:FindFirstChild("Timer") then ABHBall.Timer:Destroy() end
			if ABHBall:FindFirstChild("SpecialMesh") then ABHBall.SpecialMesh:Destroy() end

			ABHBall.TextureID = ""
			ABHBall.Color = BrickColor.Green().Color
			ABHBall.Material = Enum.Material.Neon
			ABHBall.Transparency = 0

			Debris:AddItem(ABHBall, 3)

			-- Atualiza Placar (Home GLT detectado = Ponto para Away, e vice-versa)
			local oppositeName = if GLT.Name == "Home" then "Away" else "Home"
			local scoreNumberValue = DATA_FOLDER:FindFirstChild(("%sScore"):format(oppositeName)) :: NumberValue

			if scoreNumberValue then
				scoreNumberValue.Value += 1
			end

			-- Notifica Liga
			task.delay(2, function()
				ABHLeague:GoalScored(oppositeName)
			end)

			CreateGLTConnections()
		end))
	end

	CreateGLTConnections()
end

-- Inicializa detecção para ambas as traves
task.spawn(handleGLT, HOME_GLT)
task.spawn(handleGLT, AWAY_GLT)

return {}
