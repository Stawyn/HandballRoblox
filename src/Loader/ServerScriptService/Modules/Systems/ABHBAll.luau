--[[
    ================================================================================
    MÓDULO: ABHBall
    ================================================================================
    Descrição: Sistema central de física, posse e manipulação da bola no jogo ABH.
    
    Funcionalidades:
        - Física da bola (drag, gravidade, colisão)
        - Sistema de posse (Motor6D weld)
        - Arremesso e cálculo de força
        - Detecção de tackles e saves
        - Timer de posse (5 segundos)
        - Anti-Stuck e Anti-Void
        - Integração com estatísticas (GameStatistics)
    
    Dependências:
        - Maid/Janitor: Limpeza de conexões
        - SharedTypes: Tipos compartilhados
        - TeamUtils: Verificações de times
        - GameStatistics: Registro de eventos
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: SERVIÇOS E DEPENDÊNCIAS
--// ============================================================================

local ABHBall = {}

-- Utilitários e Tipos
local Maid = require("../../../ReplicatedStorage/Utilities/Maid")
local Janitor = require("../../../ReplicatedStorage/Utilities/Janitor")
local FixedPower = require("../../../ReplicatedStorage/Modules/Implementation/ThrowPower")
local SharedTypes = require("../../../ReplicatedStorage/Utilities/SharedTypes")
local VectorLib = require("../../../ReplicatedStorage/Utilities/Vector")
local SharedAttributes = require("../../../ReplicatedStorage/Modules/Implementation/SharedAttributes")
local Utils = require("../../../ReplicatedStorage/Utilities/Utils")
local TeamUtils = require("../../../ReplicatedStorage/Utilities/TeamUtils")
local ServerEvents = require("../Implementation/ServerEvents")
local GameStatistics = require("./GameStatistics")

-- Serviços Roblox
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// ============================================================================
--// SETOR: REFERÊNCIAS E CONSTANTES
--// ============================================================================

-- Times
local HOME_TEAM = Teams:WaitForChild("Home Team")
local HOME_GK = Teams:WaitForChild("-Home Goalkeeper")
local AWAY_GK = Teams:WaitForChild("-Away Goalkeeper")
local AWAY_TEAM = Teams:WaitForChild("Away Team")

-- Instâncias do Jogo
local BALL_INSTANCE = ServerStorage:WaitForChild("ABHBall") :: SharedTypes.ABHBallInstance
local CORE_FOLDER = workspace:WaitForChild("Core")
local DATA_FOLDER = CORE_FOLDER:WaitForChild("Data") 
local BALLS_FOLDER = CORE_FOLDER:WaitForChild("Balls") 
local BALL_TIMER = DATA_FOLDER:WaitForChild("BallTimer")
local MATCH_VALUE = DATA_FOLDER:WaitForChild("Match")
local MATCH_PAUSED = DATA_FOLDER:WaitForChild("MatchPaused")
local HOME_GLT = CORE_FOLDER:WaitForChild("GLT"):WaitForChild("Home")

local NETWORK_FOLDER = ReplicatedStorage:WaitForChild("Network") :: Folder
local LEAGUE_EVENT = NETWORK_FOLDER:WaitForChild("LeagueEvent") :: RemoteEvent
local HOME_AREA = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("HomeArea") :: BasePart
local AWAY_AREA = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("AwayArea") :: BasePart

local BALL_INTERACTION_COOLDOWN = 2
local TACKLE_COOLDOWN = 0.5
local BALL_OFFSET = CFrame.new(0, -BALL_INSTANCE.Size.Y / 2, BALL_INSTANCE.Size.Z / 2)
local RELEASE_OFFSET = CFrame.new(0, 0, BALL_INSTANCE.Size.Y / 2)
local DEFAULT_BALL_TIMER = 5
local DRAG_CONSTANT = SharedAttributes:GetKDrag()
local POWER_MULTIPLIER = 170
local VERTICAL_AMPLIFIER = Vector3.new(0, 0.0375, 0)
local SAVE_FACTOR = 0.5
local VERTICAL_SAVE_LINEAR = 30
local THROW_BUFF = 1.5


local ballConnections = {}
local ballPlayersCooldown = {}
local ballMotors6D = {}
local gltInteractionCooldown = {}
local playersPositions = {}

local activeBalls = {}

local ballPositionsTrack = {}

-- Manager for ball physics to reduce individual Stepped connections
RunService.Stepped:Connect(function(deltaTime)
	local now = tick()
	for ABHBall, connections in ballConnections do
		if ABHBall:IsDescendantOf(BALLS_FOLDER) then
			-- Raposa: Tracker de movimento para Anti-Stuck
			local track = ballPositionsTrack[ABHBall]
			if not track then
				track = {lastPos = ABHBall.Position, lastTime = now}
				ballPositionsTrack[ABHBall] = track
			end

			if (ABHBall.Position - track.lastPos).Magnitude > 0.1 then
				track.lastPos = ABHBall.Position
				track.lastTime = now
			elseif not ABHBall.Anchored and now - track.lastTime > 15 then
				-- Bola imovel por 15 segundos: resetar para o meio
				ABHBall.Position = Vector3.new(0, 10, 0)
				ABHBall.AssemblyLinearVelocity = Vector3.zero
				track.lastTime = now
			end

			-- Raposa: Anti-Void
			if ABHBall.Position.Y < -10 then
				local lastThrower = ABHBall.Information.LastThrow.Value
				if lastThrower and lastThrower.Character and lastThrower.Character:FindFirstChild("Head") then
					ABHBall.Position = lastThrower.Character.Head.Position + Vector3.new(0, 20, 0)
				else
					ABHBall.Position += Vector3.new(0, 20, 0)
				end

				ABHBall.AssemblyLinearVelocity = Vector3.zero
				ABHBall.AssemblyAngularVelocity = Vector3.zero
				ABHBall.CanCollide = true
			end
			-- Fim Raposa

			-- Drag calculation
			local velocity = ABHBall.AssemblyLinearVelocity
			local appliedForce = -(velocity * DRAG_CONSTANT)
			appliedForce *= Vector3.new(1, 0, 1)
			ABHBall.ResistanceForce.Force = appliedForce
		end
	end
end)

--[[
For reference purposes.
Let A be a vector of connections for each ABHBall instance, i.e., ballConnections[ABHBall]:
A[1] := Collision
A[2] := Ball touch
A[3] := Ball timer
A[4] := Unused (formerly Air Resistance)
A[5] := Ball velocity reducer
--]]

--// ============================================================================
--// SETOR: FUNÇÕES AUXILIARES INTERNAS
--// ============================================================================

--- Inicializa conexões para uma bola
-- @param ABHBall SharedTypes.ABHBallInstance - Instância da bola
function InitConnection(ABHBall: SharedTypes.ABHBallInstance)
	ballConnections[ABHBall] = table.create(5, Maid.new())
end


--- Transformação de força de arremesso baseada em marcação
-- @param x number - Quantidade de oponentes marcando
-- @return number - Multiplicador de força
function throwPowerTransformation(x: number)
	local int = math.floor(x)
	int = math.max(0, int)

	local t = THROW_BUFF - 0.6 * math.log(int + 1)
	return math.max(0.5, t)
end

--- Conta oponentes em um raio (usa TeamUtils internamente)
-- @param blacklistPlayer Player - Jogador a ignorar
-- @param center Vector3 - Centro da busca
-- @return number - Quantidade de oponentes
local function countOpponentsInRadius(blacklistPlayer: Player, center: Vector3): number
	return TeamUtils.countOpponentsInRadius(blacklistPlayer, center, 10)
end

--// ============================================================================
--// SETOR: HANDLERS DE EVENTOS DA BOLA
--// ============================================================================

function HandleCollision(ABHBall: SharedTypes.ABHBallInstance) 
	if not ballConnections[ABHBall] then
		return
	end

	local resistanceForce = ABHBall.ResistanceForce
	local playerOnBall = ABHBall.Information.CurrentPlayerOnBall	
	ballConnections[ABHBall][1]:GiveTask(playerOnBall:GetPropertyChangedSignal("Value"):Connect(function()
		if not playerOnBall.Value then
			resistanceForce.Enabled = true
			-- IMMEDIATELY restore CanCollide when ball is released to prevent phasing
			task.spawn(function()
				local originalCanCollide = ABHBall:GetAttribute("OriginalCanCollide")
				if originalCanCollide ~= nil then
					pcall(function() ABHBall.CanCollide = originalCanCollide end)
					ABHBall:SetAttribute("OriginalCanCollide", nil)
				else
					pcall(function() ABHBall.CanCollide = true end)
				end
			end)
		else 
			resistanceForce.Enabled = false
		end
	end))
end

function ApplyBallWeld(ABHBall: SharedTypes.ABHBallInstance, player: Player)
	local character = player.Character :: Model
	local currentHand = player:GetAttribute("CurrentHand")

	local presumedHand: BasePart
	if currentHand == "L" then
		presumedHand = character:FindFirstChild("Left Arm") :: BasePart
	else
		presumedHand = character:FindFirstChild("Right Arm") :: BasePart
	end

	local existingMotor6D = ballMotors6D[ABHBall]
	if existingMotor6D then
		existingMotor6D:Destroy()
	end

	local motor6D = Instance.new("Motor6D")
	motor6D.Name = "BallOwnership"
	motor6D.Part0 = presumedHand
	motor6D.Part1 = ABHBall
	motor6D.C0 = BALL_OFFSET
	motor6D.Parent = character

	ballMotors6D[ABHBall] = motor6D

	ABHBall.Trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, player.TeamColor.Color),
		ColorSequenceKeypoint.new(1, player.TeamColor.Color)
	})
	ballPlayersCooldown[ABHBall][player.UserId] = os.clock()

	-- Store original CanCollide state before modifying
	-- This prevents camera issues while maintaining proper physics when released
	if not ABHBall:GetAttribute("OriginalCanCollide") then
		ABHBall:SetAttribute("OriginalCanCollide", ABHBall.CanCollide)
	end
	ABHBall.CanCollide = false
end

function HandleBallTouch(ABHBall: SharedTypes.ABHBallInstance)
	if not ballConnections[ABHBall] then
		return
	end

	local informationFolder = ABHBall.Information
	local lastThrow = informationFolder.LastThrow

	ballConnections[ABHBall][2]:GiveTask(ABHBall.Touched:Connect(function(otherPart)		
		if otherPart.Name == "Nets" then
			ABHBall.AssemblyLinearVelocity = Vector3.zero
			ABHBall.AssemblyAngularVelocity = Vector3.zero
			return
		end

		local player = Players:GetPlayerFromCharacter(otherPart.Parent :: Model)
		if not player then
			return
		end
		local playerPing = (player.leaderstats.Ping :: NumberValue).Value
		if playerPing >= SharedAttributes:MaxPing() then
			return
		end

		--Raposa adicionou
		if MATCH_PAUSED.Value then
			return
		end
		--Fim Raposa

		ABHBall.Anchored = false

		if not informationFolder.CanTackle.Value then
			return
		end
		if informationFolder.CurrentPlayerOnBall.Value then
			return
		end
		if ABHBall:GetAttribute("Saved")== true then
			return
		end

		local character = player.Character
		if not character then
			return
		end

		local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
		if not humanoid or humanoid.Health <= 0 then
			return
		end
		
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not humanoidRootPart then
			return
		end

		if character:FindFirstChild("BallOwnership") then 
			return
		end
		
		-- Ricochetear bola se o jogador estiver com KeeperTool equipada (nunca captura)
		if character:FindFirstChild("KeeperTool") then
			local hrp = humanoidRootPart
			if hrp then
				-- SEMPRE ricochetear, independente da velocidade da bola
				local currentVelocity = ABHBall.AssemblyLinearVelocity.Magnitude
				local bounceDirection = (ABHBall.Position - hrp.Position).Unit
				
				-- Se a bola está parada ou lenta, aplicar velocidade mínima de 20
				local bounceSpeed = math.max(currentVelocity * 0.6, 20)
				bounceSpeed = math.clamp(bounceSpeed, 20, 70)
				
				ABHBall.AssemblyLinearVelocity = bounceDirection * bounceSpeed + Vector3.new(0, 18, 0)
				ABHBall.AssemblyAngularVelocity = Vector3.zero
				
				-- Cooldown para evitar múltiplos ricochetes seguidos
				if not ballPlayersCooldown[ABHBall] then ballPlayersCooldown[ABHBall] = {} end
				ballPlayersCooldown[ABHBall][player.UserId] = os.clock()
				
				-- Registrar estatística de Save se foi um chute
				local wasShot = ABHBall:GetAttribute("IsShot") or ABHBall:GetAttribute("IsSOG")
				if wasShot and not ABHBall:GetAttribute("Saved") then
					ABHBall:SetAttribute("Saved", true)
					GameStatistics.RecordEvent(player, "Save")
					local shooter = informationFolder.LastThrow.Value :: Player?
					if shooter and shooter ~= player then
						GameStatistics.RecordEvent(shooter, "SavedShot")
						GameStatistics.RecordEvent(shooter, "SOG")
					end
					task.delay(0.5, function()
						if ABHBall and ABHBall.Parent then
							ABHBall:SetAttribute("Saved", false)
						end
					end)
				end
			end
			return -- SEMPRE retorna, nunca permite captura
		end

		local forceField = ABHBall:FindFirstChild("ForceField")
		if forceField then
			local takerUserId = forceField:GetAttribute("TakerUserId")
			local ignore = forceField:GetAttribute("Ignore")
			if takerUserId and not ignore then
				if takerUserId ~= player.UserId then
					return
				end
			end
		end

		local playerCooldown = ballPlayersCooldown[ABHBall][player.UserId] :: number?
		if playerCooldown then
			local lastInteraction = os.clock() - playerCooldown
			if lastInteraction <= BALL_INTERACTION_COOLDOWN then
				return
			end
		end

		if MATCH_VALUE.Value then
			if lastThrow.Value and lastThrow.Value ~= player then
				if Utils:IsPointInHomeArea(humanoidRootPart.Position) then
					if (player.Team and player.Team.Name == "-Home Goalkeeper" and lastThrow.Value and lastThrow.Value.Team and lastThrow.Value.Team.Name:find("Home")) then
						for u, w in Teams.Officials:GetPlayers() do
							LEAGUE_EVENT:FireClient(w, "POSSIBLE_PASSBACK", true)
						end
					end
				end
			elseif Utils:IsPointInAwayArea(humanoidRootPart.Position) then
				if (player.Team and player.Team.Name == "-Away Goalkeeper" and lastThrow.Value and lastThrow.Value.Team and lastThrow.Value.Team.Name:find("Away")) then
					for u, w in Teams.Officials:GetPlayers() do
						LEAGUE_EVENT:FireClient(w, "POSSIBLE_PASSBACK", false)
					end
				end
			end
		end

		local vectorForce = ABHBall:FindFirstChild("VerticalForce") :: VectorForce
		if vectorForce then
			vectorForce:Destroy()
		end
		informationFolder.CanTackle.Value = false

		--Raposa adicionou
		-- Prefer the persisted LastThrowUserId attribute (more robust across timing) and fall back to Information.LastThrow
		local lastThrowUserId = ABHBall:GetAttribute("LastThrowUserId") or (informationFolder.LastThrow.Value and informationFolder.LastThrow.Value.UserId)
		local lastThrower = nil
		if lastThrowUserId then
			lastThrower = Players:GetPlayerByUserId(lastThrowUserId)
		else
			lastThrower = informationFolder.LastThrow.Value
		end
		-- Optional freshness check (avoid attributing very old throws)
		local lastThrowTime = ABHBall:GetAttribute("LastThrowTime")
		if lastThrowTime and (os.time() - lastThrowTime) > 15 then
			lastThrower = nil
		end
		-- Only attribute pass/turnover if we actually have a lastThrower and it's not the same player
		-- Raposa: Now even shots count towards pass completion/turnover (as requested)
		if lastThrower and lastThrower ~= player then
			if TeamUtils.areSameTeam(lastThrower, player) then
				GameStatistics.RecordEvent(lastThrower, "PassComplete")
			else
				GameStatistics.RecordEvent(lastThrower, "PassFailed") -- Raposa: Count as failed pass
				GameStatistics.RecordEvent(lastThrower, "Turnover")
			end
		end

		-- Verificar se foi um chute para estatísticas de goleiro
		local wasShot = ABHBall:GetAttribute("IsShot") or ABHBall:GetAttribute("IsSOG")
		if player.Team and player.Team.Name:find("Goalkeeper") then
			if wasShot then
				-- Fix Race Condition #C4: Remover lógica de reset duplicada
				ABHBall:SetAttribute("IsSOG", true)
				ABHBall:SetAttribute("Saved", true)
				
				local shooter = ABHBall.Information.LastThrow.Value :: Player?
				if shooter and shooter ~= player then
					GameStatistics.RecordEvent(player, "Save") -- Moved inside to prevent double counting on touch
					GameStatistics.RecordEvent(shooter, "SavedShot")
				end
			end
		end
		--Fim Raposa

		ABHBall.AssemblyLinearVelocity = Vector3.zero
		ABHBall.AssemblyAngularVelocity = Vector3.zero
		ApplyBallWeld(ABHBall, player)
		informationFolder.CurrentPlayerOnBall.Value = player
		task.wait(TACKLE_COOLDOWN)
		if not ABHBall:IsDescendantOf(BALLS_FOLDER) then
			return
		end
		informationFolder.CanTackle.Value = true
	end))
end

function HandleBallTimer(ABHBall: SharedTypes.ABHBallInstance)
	local informationFolder = ABHBall.Information
	local currentPlayerOnBall = informationFolder.CurrentPlayerOnBall
	local lastPlayerOnBall = informationFolder.LastPlayerOnBall
	local lastThrow = informationFolder.LastThrow
	local thread: thread?

	ballConnections[ABHBall][3]:GiveTask(currentPlayerOnBall:GetPropertyChangedSignal("Value"):Connect(function()
		local oldPlayerOnBall = currentPlayerOnBall.Value

		--Raposa adicionou
		if currentPlayerOnBall.Value then
			GameStatistics.RecordEvent(currentPlayerOnBall.Value, "PossessionStart")
			-- Atualizar name tag
			local tag = ABHBall:FindFirstChild("SpawnerTag")
			if tag and tag:FindFirstChildOfClass("TextLabel") then
				tag:FindFirstChildOfClass("TextLabel").Text = currentPlayerOnBall.Value.Name
			end
		else
			-- Limpar name tag ao soltar/perder a bola
			local tag = ABHBall:FindFirstChild("SpawnerTag")
			if tag and tag:FindFirstChildOfClass("TextLabel") then
				tag:FindFirstChildOfClass("TextLabel").Text = ""
			end
		end
		--Fim Raposa

		if not currentPlayerOnBall.Value then 
			if thread ~= nil then
				coroutine.close(thread)
				thread = nil
			end
			return
		end

		if thread ~= nil then
			coroutine.close(thread)
		end

		if currentPlayerOnBall.Value == lastThrow.Value and lastPlayerOnBall.Value == lastThrow.Value then
			local lastPosition = ABHBall.Position
			ABHBall.Timer.Seconds.TextColor3 = Color3.fromRGB(255, 0, 0)
			ABHBall.Timer.Seconds.Text = tostring((currentPlayerOnBall.Value :: Instance).Name)
			ABHBall.CanTouch = false

			local playerInstance = currentPlayerOnBall.Value :: Player?
			if playerInstance then
				if playerInstance.Character then
					local ownership = (playerInstance.Character :: Model):FindFirstChild("BallOwnership")
					if ownership then
						ownership:Destroy()
					end
				end

				--Raposa: Acionar falta e erro na estatistica
				local playerTeamName = playerInstance.Team.Name
				local isGK = playerTeamName:find("Goalkeeper")
				local isHome = playerTeamName:find("Home")

				if MATCH_VALUE.Value then
					ServerEvents.League:Fire("BALL_TIME_VIOLATION", playerInstance)
					if isGK then
						ServerEvents.League:Fire("PENALTY", not isHome, isHome)
					else
						ServerEvents.League:Fire("FREE_THROW", lastPosition, not isHome)
					end
					GameStatistics.RecordEvent(playerInstance, "Turnover")
				end
			end

			currentPlayerOnBall.Value = nil
			ABHBall.AssemblyLinearVelocity = Vector3.zero
			ABHBall.AssemblyAngularVelocity = Vector3.zero
			local vectorForce = ABHBall:FindFirstChild("VerticalForce")
			if vectorForce then
				vectorForce:Destroy()
			end

			ABHBall.Anchored = true
			ABHBall.CanCollide = false
			ABHBall.Material = Enum.Material.Neon

			if playerInstance then
				ABHBall.Color = playerInstance.TeamColor.Color
			else
				ABHBall.Color = Color3.fromRGB(255, 255, 255)
			end

			ABHBall.TextureID = ""
			Debris:AddItem(ABHBall, 3)
			return
		end

		if currentPlayerOnBall.Value then
			ABHBall.Timer.Seconds.TextColor3 = Color3.fromRGB(255, 255, 255)
			informationFolder.Timer.Value = DEFAULT_BALL_TIMER
			ABHBall.Timer.Seconds.Text = string.format("%.1f", informationFolder.Timer.Value)
		end

		thread = coroutine.create(function()		
			while currentPlayerOnBall.Value and ABHBall:IsDescendantOf(BALLS_FOLDER) do
				task.wait(0.1)
				--Raposa adicionou
				if currentPlayerOnBall.Value then
					GameStatistics.RecordEvent(currentPlayerOnBall.Value, "Possession", 0.1)
				end
				--Fim Raposa

				local playerOnBall = currentPlayerOnBall.Value
				local isGK = playerOnBall and playerOnBall.Team.Name:find("Goalkeeper")
				local isImmune = ABHBall:FindFirstChild("ForceField") or ABHBall:FindFirstChild("RefereeImmunity") or ABHBall:GetAttribute("Saved") == true

				-- O goleiro deve contar o countdown mesmo se tiver imunidade (ForceField), conforme pedido.
				if BALL_TIMER.Value and (not isImmune or isGK) then
					if informationFolder.Timer.Value <= 0 then
						break
					end

					if oldPlayerOnBall ~= currentPlayerOnBall.Value then
						break
					end

					informationFolder.Timer.Value -= 0.1
					ABHBall.Timer.Seconds.Text = string.format("%.1f", informationFolder.Timer.Value)
				end
			end

			if not ABHBall:IsDescendantOf(BALLS_FOLDER) then
				return
			end

			if informationFolder.Timer.Value <= 0 and currentPlayerOnBall.Value then
				local lastPosition = ABHBall.Position

				ABHBall.Timer.Seconds.TextColor3 = Color3.fromRGB(255, 0, 0)
				ABHBall.Timer.Seconds.Text = tostring((currentPlayerOnBall.Value :: Instance).Name)
				ABHBall.CanTouch = false

				local playerInstance = currentPlayerOnBall.Value :: Player
				if playerInstance.Character then
					local ownership = (playerInstance.Character :: Model):FindFirstChild("BallOwnership")
					if ownership then
						ownership:Destroy()
					end
				end

				-- Raposa: Acionar infracao por tempo expirado
				local playerTeamName = playerInstance.Team.Name
				local isGK = playerTeamName:find("Goalkeeper")
				local isHome = playerTeamName:find("Home")

				if MATCH_VALUE.Value then
					ServerEvents.League:Fire("BALL_TIME_VIOLATION", playerInstance)
					if isGK then
						ServerEvents.League:Fire("PENALTY", not isHome, isHome)
					else
						ServerEvents.League:Fire("FREE_THROW", lastPosition, not isHome)
					end
					GameStatistics.RecordEvent(playerInstance, "Turnover")
				end

				currentPlayerOnBall.Value = nil
				ABHBall.AssemblyLinearVelocity = Vector3.zero
				ABHBall.AssemblyAngularVelocity = Vector3.zero
				local vectorForce = ABHBall:FindFirstChild("VerticalForce")
				if vectorForce then
					vectorForce:Destroy()
				end

				ABHBall.Anchored = true
				ABHBall.CanCollide = false
				ABHBall.Material = Enum.Material.Neon

				ABHBall.Color = playerInstance.TeamColor.Color

				ABHBall.TextureID = ""
				Debris:AddItem(ABHBall, 3)
			end
		end)

		coroutine.resume(thread)
	end))
end



function HandleBallAirResistance(ABHBall: SharedTypes.ABHBallInstance)
	-- Logic moved to central Stepped loop for performance
end


function CalculatePower(startingCFrame: CFrame, directionData: SharedTypes.DirectionData, power: number, player: Player)
	local calculatedPower = math.sqrt(power / 100) * POWER_MULTIPLIER
	local hrp = player.Character.HumanoidRootPart
	local fixedPower = FixedPower(directionData.mouseDirection, directionData.mousePosition, directionData.humanoidRootPartDirection, calculatedPower, hrp.Position, player)
	calculatedPower = fixedPower


	local direction = VectorLib:VectorLibToVector3(directionData.mouseDirection)

	local releasePosition = startingCFrame * RELEASE_OFFSET
	local velocity = (direction + VERTICAL_AMPLIFIER) * calculatedPower

	return {
		releasePosition, velocity
	}
end

function ABHBall:Ghostball(ballInstance: SharedTypes.ABHBallInstance)
	local ghost = ballInstance:Clone()
	ballInstance:Destroy()

	ghost.CanTouch = false
	ghost.AssemblyLinearVelocity = Vector3.zero
	ghost.AssemblyAngularVelocity = Vector3.zero
	ghost.Anchored = true
	ghost.Timer:Destroy()
	ghost.SpecialMesh:Destroy()
	ghost.TextureID = ""
	ghost.BrickColor = BrickColor.White()
	ghost.Material = Enum.Material.Neon
	ghost.Parent = workspace
	Debris:AddItem(ghost, 3)
end

function ABHBall:ApplyVerticalForce(ABHBall: SharedTypes.ABHBallInstance)
	local forceMaid = Maid.new()
	local yForce = ABHBall:GetMass() * workspace.Gravity * 0.75

	local existingForce = ABHBall:FindFirstChild("VerticalForce")
	if existingForce then
		return
	end

	local vectorForce = Instance.new("VectorForce")
	vectorForce.Name = "VerticalForce"
	local baseBallForce = vector.create(0, yForce, 0)
	vectorForce.Force = baseBallForce
	vectorForce.RelativeTo = Enum.ActuatorRelativeTo.World
	vectorForce.Attachment0 = ABHBall.Middle
	vectorForce.ApplyAtCenterOfMass = true
	vectorForce.Parent = ABHBall

	task.delay(0.125, function()
		forceMaid:GiveTask(ABHBall.Touched:Connect(function(touchingPart)
			if touchingPart.Name == "RealField" then
				return
			end
			if touchingPart.Name == "FieldGrass" then 
				return
			end
			if touchingPart.Name == "ABHBall" then
				return
			end
			if touchingPart.Name == "ForceField" then
				return
			end
			if touchingPart.Name == "Area" or touchingPart.Name == "HomeArea" or touchingPart.Name == "AwayArea" then
				return
			end
			if touchingPart.Name == "Grass" then
				return
			end
			if touchingPart.Name == "Barrier" then
				return
			end
			if Players:GetPlayerFromCharacter(touchingPart.Parent :: Model) then
				return
			end
			if touchingPart.Name == "Handle" then
				return
			end

			vectorForce:Destroy()
			forceMaid:Destroy()
		end))
	end)
end

function BallVelocityReducer(ABHBall: SharedTypes.ABHBallInstance)
	ballConnections[ABHBall][5]:GiveTask(ABHBall.Touched:Connect(function(child)
		if not ABHBall:IsDescendantOf(workspace) then
			return
		end
		if child.Name ~= "RealField" then
			return
		end
		if ABHBall.Information.CurrentPlayerOnBall.Value ~= nil then
			return
		end

		ABHBall.AssemblyLinearVelocity *= 0.97
	end))
end

function ABHBall:Create(cframe: CFrame, spawner: Player?)	
	local protectConnection = Janitor.new()

	-- Raposa: Regra de Bola Unica durante partida
	if MATCH_VALUE.Value then
		for _, existingBall in ipairs(BALLS_FOLDER:GetChildren()) do
			pcall(function() existingBall:Destroy() end)
		end
	end

	local instance = BALL_INSTANCE:Clone()
	instance.Name = HttpService:GenerateGUID()
	instance.CFrame = cframe

	-- Raposa: Criar/Ajustar Tag de Nome (SpawnerTag) e Timer
	local nameTag = instance:FindFirstChild("SpawnerTag")
	if not nameTag then
		nameTag = Instance.new("BillboardGui")
		nameTag.Name = "SpawnerTag"
		nameTag.Size = UDim2.new(0, 100, 0, 20)
		nameTag.AlwaysOnTop = true

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0
		label.Font = Enum.Font.GothamBold
		label.TextSize = 12
		label.Parent = nameTag

		nameTag.Parent = instance
	end

	nameTag.StudsOffset = Vector3.new(0, 1.2, 0) -- Abaixo dos segundos (2.0)
	nameTag.MaxDistance = 50 -- Nao visto de longe
	local label = nameTag:FindFirstChildOfClass("TextLabel")
	if label then
		-- Raposa: Remover nome se for partida
		if MATCH_VALUE.Value then
			label.Text = ""
		else
			label.Text = if spawner then spawner.Name else ""
		end
	end

	if instance:FindFirstChild("Timer") then
		instance.Timer.StudsOffset = Vector3.new(0, 2.0, 0) -- Segundos em cima
		instance.Timer.MaxDistance = 50 -- Nao visto de longe
	end

	playersPositions[instance] = {}
	ballPlayersCooldown[instance] = {}
	ballMotors6D[instance] = nil
	instance:SetAttribute("Saved", false)
	instance.Information.CanTackle.Value = true
	instance.CanCollide = true -- Raposa: Garantir colisao ao criar

	-- Raposa: Garantir que o Timer existe na pasta Information
	if not instance.Information:FindFirstChild("Timer") then
		local timerValue = Instance.new("NumberValue")
		timerValue.Name = "Timer"
		timerValue.Value = DEFAULT_BALL_TIMER
		timerValue.Parent = instance.Information
	end

	coroutine.wrap(InitConnection)(instance)

	coroutine.wrap(HandleCollision)(instance)
	coroutine.wrap(HandleBallTouch)(instance)
	coroutine.wrap(HandleBallAirResistance)(instance)
	coroutine.wrap(BallVelocityReducer)(instance)
	task.spawn(HandleBallTimer, instance)

	instance.Information.Timer.Value = DEFAULT_BALL_TIMER

	instance.Destroying:Connect(function()
		for _, connection in ballConnections[instance] do
			connection:DoCleaning()
		end

		table.clear(playersPositions[instance])
		table.clear(ballPlayersCooldown[instance])
		if ballMotors6D[instance] then
			ballMotors6D[instance]:Destroy()
			ballMotors6D[instance] = nil
		end

		gltInteractionCooldown[instance] = nil
		ballConnections[instance] = nil
	end)

	local forceField = instance.ForceField
	forceField:SetAttribute("TakerUserId", 0)
	protectConnection:LinkToInstance(forceField)
	protectConnection:Add(forceField:GetAttributeChangedSignal("TakerUserId"):Connect(function()
		local userId = forceField:GetAttribute("TakerUserId")
		if not userId or userId == 0 then
			return
		end

		local player = Players:GetPlayerByUserId(userId)
		local character = player and player.Character
		local primaryPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not primaryPart then
			return
		end

		-- Raposa: Anular velocidade ao tocar no ForceField (levar TP)
		primaryPart.AssemblyLinearVelocity = Vector3.zero
		primaryPart.AssemblyAngularVelocity = Vector3.zero

		local linearVelocity = Instance.new("LinearVelocity")
		linearVelocity.Attachment0 = primaryPart:FindFirstChild("RootAttachment") or Instance.new("Attachment", primaryPart)
		linearVelocity.MaxForce = math.huge
		linearVelocity.VectorVelocity = vector.zero
		linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
		linearVelocity.Enabled = false
		linearVelocity.Parent = primaryPart

		protectConnection:Add(linearVelocity, "Destroy")

		-- Raposa: Travar pulo e caminhada
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local oldJumpPower = humanoid.JumpPower
			local oldJumpHeight = humanoid.JumpHeight
			local oldWalkSpeed = humanoid.WalkSpeed
			local currentlyApplied = false

			local function update()
				local player = Players:GetPlayerFromCharacter(character)
				local hasBall = character:FindFirstChild("BallOwnership") ~= nil
				local isSwitching = player and player:GetAttribute("SwitchingHands") == true

				local shouldApply = hasBall and not isSwitching

				if shouldApply then
					if not currentlyApplied then
						currentlyApplied = true
						-- Salva os valores atuais antes de zerar
						oldJumpPower = humanoid.JumpPower
						oldJumpHeight = humanoid.JumpHeight
						oldWalkSpeed = humanoid.WalkSpeed

						humanoid.JumpPower = 0
						humanoid.JumpHeight = 0
						humanoid.WalkSpeed = 0
						linearVelocity.Enabled = true
					end
				else
					if currentlyApplied then
						currentlyApplied = false
						-- Restaura os valores originais
						humanoid.JumpPower = oldJumpPower
						humanoid.JumpHeight = oldJumpHeight
						humanoid.WalkSpeed = oldWalkSpeed
						linearVelocity.Enabled = false
					end
				end
			end

			protectConnection:Add(character.ChildAdded:Connect(function(child)
				if child.Name == "BallOwnership" then update() end
			end), "Disconnect")
			protectConnection:Add(character.ChildRemoved:Connect(function(child)
				if child.Name == "BallOwnership" then update() end
			end), "Disconnect")

			local player = Players:GetPlayerFromCharacter(character)
			if player then
				protectConnection:Add(player:GetAttributeChangedSignal("SwitchingHands"):Connect(update), "Disconnect")
			end

			update()

			protectConnection:Add(function()
				if currentlyApplied then
					if humanoid and humanoid.Parent then
						humanoid.JumpPower = oldJumpPower
						humanoid.JumpHeight = oldJumpHeight
						humanoid.WalkSpeed = oldWalkSpeed
					end
				end
			end)
		end
	end), "Disconnect")

	if MATCH_PAUSED.Value then
		instance.Anchored = true
		pcall(function() instance.CanCollide = false end)
		pcall(function() instance.CanTouch = false end)
		instance:SetAttribute("Paused", true)
	end

	instance.Parent = BALLS_FOLDER
	return instance
end

function ABHBall:Throw(player: Player, instance: SharedTypes.ABHBallInstance, directionData: SharedTypes.DirectionData, power: number)
	local data = CalculatePower(instance.CFrame, directionData, power, player)
	local releasePosition = data[1] :: CFrame
	local velocity = data[2] :: Vector3

	-- Lag Compensation: Advance the ball starting position based on player ping
	local playerPing = 0
	pcall(function()
		playerPing = player.leaderstats.Ping.Value / 1000 -- Convert ms to seconds
	end)

	-- Limited lag compensation to avoid clipping through distant walls
	local leadTime = math.min(playerPing, 0.15) 
	local advancedPosition = releasePosition.Position + (velocity * leadTime)

	-- We only advance if it doesn't hit anything immediately
	local leadRay = workspace:Raycast(releasePosition.Position, velocity * leadTime, RaycastParams.new())
	if not leadRay then
		releasePosition = releasePosition - releasePosition.Position + advancedPosition
	end

	if ballMotors6D[instance] then
		ballMotors6D[instance]:Destroy()
		ballMotors6D[instance] = nil
	end

	local character = player.Character
	if character then
		local ballOwnership = character:FindFirstChild("BallOwnership")
		if ballOwnership then
			ballOwnership:Destroy()
		end
	end

	if instance:FindFirstChild("RefereeImmunity") then
		(instance.RefereeImmunity :: Instance):Destroy()
	end
	if instance:FindFirstChild("ForceField") then
		(instance.ForceField):Destroy()
	end

	-- Raposa: Atualiza o ultimo jogador que atirou para o watchdog do ABHLeague
	ServerEvents.League:Fire("PLAYER_THROW", player)

	--Raposa adicionou: Every throw counts as a pass attempt
	GameStatistics.RecordEvent(player, "PassAttempt")

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {HOME_GLT, AWAY_GLT}
	raycastParams.FilterType = Enum.RaycastFilterType.Include

	local result = workspace:Raycast(releasePosition.Position, vector.normalize(directionData.mouseDirection) * 77, raycastParams)
	local multiplier = 1

	-- Determine if the throw was aimed at the opponent's goal (shot attempt)
	local isAimedAtGoal = false
	local playerTeamName = (player.Team and player.Team.Name) or ""
	local goalPos = nil
	if playerTeamName:find("Home") then
		goalPos = AWAY_GLT and AWAY_GLT.Position or nil
	else
		goalPos = HOME_GLT and HOME_GLT.Position or nil
	end
	if goalPos then
		local aimDir = vector.normalize(directionData.mouseDirection)
		local toGoal = goalPos - releasePosition.Position
		if toGoal.Magnitude > 0 then
			local toGoalDir = toGoal.Unit
			local dot = aimDir:Dot(toGoalDir)
			-- dot threshold 0.6 ~= ~53 degrees; adjust if needed
			if dot >= 0.6 then
				isAimedAtGoal = true
			end
		end
	end

	if result then
		-- Ball path intersects goal (Shot on Goal)
		instance:SetAttribute("IsSOG", true)
		instance:SetAttribute("IsShot", true)
		local markingQtd = countOpponentsInRadius(player, character.HumanoidRootPart.Position)
		multiplier = throwPowerTransformation(markingQtd)
	elseif isAimedAtGoal then
		-- Aimed at goal but didn't intersect GLT (wide shot) -> consider as shot attempt
		instance:SetAttribute("IsSOG", false)
		instance:SetAttribute("IsShot", true)
	else
		-- Regular pass
		instance:SetAttribute("IsSOG", false)
		instance:SetAttribute("IsShot", false)
	end
	--Fim Raposa

	instance.CFrame = releasePosition
	-- Correcao Raposa: Garantir que a bola nao seja solta embaixo do chao
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {BALLS_FOLDER, player.Character}
	local rayResult = workspace:Raycast(releasePosition.Position + Vector3.new(0, 2, 0), Vector3.new(0, -4, 0), rayParams)
	if rayResult then
		local floorHeight = rayResult.Position.Y
		local ballRadius = instance.Size.Y / 2
		if instance.Position.Y < floorHeight + ballRadius then
			instance.CFrame = (releasePosition - releasePosition.Position) + Vector3.new(releasePosition.Position.X, floorHeight + ballRadius + 0.05, releasePosition.Position.Z)
		end
	end

	-- Restore original CanCollide state when throwing
	local originalCanCollide = instance:GetAttribute("OriginalCanCollide")
	if originalCanCollide ~= nil then
		instance.CanCollide = originalCanCollide
		instance:SetAttribute("OriginalCanCollide", nil)
	else
		instance.CanCollide = true -- Default to enabled if not set
	end

	ABHBall:ApplyVerticalForce(instance)

	ballPlayersCooldown[instance][player.UserId] = os.clock()
	if instance.Information.LastThrow.Value ~= instance.Information.LastLastThrow.Value then
		instance.Information.LastLastThrow.Value = instance.Information.LastThrow.Value
	end
	instance.Information.LastThrow.Value = player
	-- Persist last throw user id and timestamp on the physical ball for robust pass detection
	pcall(function()
		instance:SetAttribute("LastThrowUserId", player.UserId)
		instance:SetAttribute("LastThrowTime", os.time())
	end)
	instance.Information.LastPlayerOnBall.Value = instance.Information.CurrentPlayerOnBall.Value
	instance.Information.CurrentPlayerOnBall.Value = nil
	instance.AssemblyAngularVelocity = Vector3.zero
	instance.AssemblyLinearVelocity = velocity * multiplier --Adicionado * multiplier
end

function ABHBall:DoCleaning()
	for _, instance in BALLS_FOLDER:GetChildren() do
		instance:Destroy()
	end
end

function ABHBall:GetGLTCooldown(instance: SharedTypes.ABHBallInstance)
	return gltInteractionCooldown[instance]
end

function ABHBall:SetGLTCooldown(instance: SharedTypes.ABHBallInstance, state: boolean)
	gltInteractionCooldown[instance] = state
end

function ABHBall:HandleGoalkeeperSave(instance: SharedTypes.ABHBallInstance, cframe: CFrame, player: Player)
	if not instance:FindFirstChild("Information") then
		return
	end
	if instance.Information.CurrentPlayerOnBall.Value then
		return
	end

	if instance:GetAttribute("Saved") == true then
		return
	end

	--Raposa adicionou
	local wasShot = instance:GetAttribute("IsShot") or instance:GetAttribute("IsSOG")
	if wasShot then
		instance:SetAttribute("IsSOG", true)
		instance:SetAttribute("Saved", true)
		GameStatistics.RecordEvent(player, "Save")
		local shooter = instance.Information.LastThrow.Value :: Player?
		if shooter and shooter ~= player then
			-- SavedShot (increment SavedShots) and also count as SOG (Shots + SOG)
			GameStatistics.RecordEvent(shooter, "SavedShot")
			GameStatistics.RecordEvent(shooter, "SOG")
		end
	end
	ABHBall:SetGLTCooldown(instance, true)
	--Fim Raposa	
	local vectorForce = instance:FindFirstChild("VectorForce")
	if vectorForce then
		vectorForce:Destroy()
	end

	local velocity = instance.AssemblyLinearVelocity :: Vector3
	local multiplier = math.clamp(instance.AssemblyLinearVelocity.Magnitude, 15, 90)
	local ballVelocity = cframe.LookVector.Unit * multiplier

	local releasePosition = cframe * RELEASE_OFFSET
	local velocity = ballVelocity + Vector3.new(0, VERTICAL_SAVE_LINEAR, 0)
	ABHBall:ApplyVerticalForce(instance)
	instance.CFrame = releasePosition
	instance.AssemblyAngularVelocity = Vector3.new()
	instance.AssemblyLinearVelocity = velocity
	instance.Information.CurrentPlayerOnBall.Value = nil
	if instance.Information.LastThrow.Value ~= instance.Information.LastLastThrow.Value then
		instance.Information.LastLastThrow.Value = instance.Information.LastThrow.Value
	end
	instance.Information.LastThrow.Value = player
	
	-- Segurança: Garantir reset seguro do atributo Saved e cooldown
	task.delay(0.5, function()
		if instance and instance.Parent then
			instance:SetAttribute("Saved", false)
			ABHBall:SetGLTCooldown(instance, false)
		end
	end)
end

function ABHBall:HandleTackle(instance: SharedTypes.ABHBallInstance, player: Player)	
	--Raposa adicionou
	if MATCH_PAUSED.Value then
		return
	end
	--Fim Raposa

	local character = player.Character
	if not character then
		return
	end

	local playerCooldown = ballPlayersCooldown[instance][player.UserId] :: number?
	if playerCooldown then
		local lastInteraction = os.clock() - playerCooldown
		if lastInteraction <= BALL_INTERACTION_COOLDOWN then
			return
		end
	end

	local ballOwnership = character:FindFirstChild("BallOwnership") :: Motor6D
	if ballOwnership then
		return
	end

	local canTackle = instance.Information.CanTackle.Value 
	if not canTackle then
		return
	end

	if instance:FindFirstChild("ForceField") then
		return
	end

	local playerPing = (player.leaderstats.Ping :: NumberValue).Value
	if playerPing >= SharedAttributes:MaxPing() then
		return
	end

	local forceField = instance:FindFirstChild("ForceField")
	if forceField then
		local isHome = forceField:GetAttribute("isHome")
		local team = (player.Team :: Team).Name

		if isHome and not team:find("Home") then
			return
		end
		if not isHome and team:find("Home") then
			return
		end
	end

	instance.Information.CanTackle.Value = false
	local vectorForce = instance:FindFirstChild("VerticalForce")
	if vectorForce then
		vectorForce:Destroy()
	end

	if ballMotors6D[instance] then
		ballMotors6D[instance]:Destroy()
		ballMotors6D[instance] = nil
	end

	local currentPlayer = instance.Information.CurrentPlayerOnBall.Value :: Player
	if currentPlayer then
		local cpCharacter = currentPlayer.Character
		if cpCharacter then
			local cpBallOwnership = cpCharacter:FindFirstChild("BallOwnership") :: Motor6D
			if cpBallOwnership then
				cpBallOwnership:Destroy()
			end
		end
	end

	instance.Information.LastPlayerOnBall.Value = currentPlayer

	-- Record a steal if the ball was taken from an opposing player
	if currentPlayer and currentPlayer ~= player then
		local currentTeam = (currentPlayer.Team and currentPlayer.Team.Name) or ""
		local playerTeam = (player.Team and player.Team.Name) or ""
		local tookFromOpposingTeam = false
		if (currentTeam:find("Home") and not playerTeam:find("Home")) or (currentTeam:find("Away") and not playerTeam:find("Away")) then
			tookFromOpposingTeam = true
		end
		if tookFromOpposingTeam then
			-- Count as a steal for tackler, and a turnover for the previous possessor
			GameStatistics.RecordEvent(player, "Steal")
			GameStatistics.RecordEvent(currentPlayer, "Turnover")
		end
	end

	instance.AssemblyLinearVelocity = Vector3.zero
	instance.AssemblyAngularVelocity = Vector3.zero
	ApplyBallWeld(instance, player)
	instance.Information.CurrentPlayerOnBall.Value = player

	task.wait(0.5)

	instance.Information.CanTackle.Value = true
end

return ABHBall



