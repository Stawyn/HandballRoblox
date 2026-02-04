--[[
    ================================================================================
    MÓDULO: ABHBallClient
    ================================================================================
    Descrição: Lógica visual da bola no cliente - animações de bounce e hold.
               Gerencia a animação de quicar quando jogador tem posse.
    
    Funcionalidades:
        - Animação de bounce (bola quicando na mão)
        - Sincronização com posse (CurrentPlayerOnBall)
        - Cleanup automático ao perder posse
        - Integração com animações de charge/throw
    
    Constantes:
        - BOUNCE_COOLDOWN: 0.25s entre cada bounce
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: SERVIÇOS E DEPENDÊNCIAS
--// ============================================================================

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedTypes = require("../../Utilities/SharedTypes")
local ABHAnimations = require("../../Utilities/ABHAnimations")
local Maid = require("../../Utilities/Maid")

--// ============================================================================
--// SETOR: CONSTANTES E REFERÊNCIAS
--// ============================================================================

local BOUNCE_COOLDOWN = 0.25
local BALLS_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Balls") :: Folder
local MATCH_PAUSED = workspace:WaitForChild("Core"):WaitForChild("Data"):WaitForChild("MatchPaused") :: BoolValue

-- Network
local NETWORK_FOLDER = ReplicatedStorage:WaitForChild("Network") :: Folder
local REFEREE_EVENT_REMOTE = NETWORK_FOLDER:WaitForChild("Referee") :: RemoteEvent

local localPlayer = Players.LocalPlayer

--// ============================================================================
--// SETOR: FUNÇÕES DE ANIMAÇÃO
--// ============================================================================

--- Verifica se animações de charge estão tocando
-- @param animator Animator - Animator do personagem
-- @return boolean - true se alguma animação de charge está tocando
local function isChargingAnimationPlaying(animator: Animator): boolean
	local animationsTrackPlaying = animator:GetPlayingAnimationTracks()
	
	for _, track: AnimationTrack in animationsTrackPlaying do
		local animationId = track.Animation.AnimationId
		if 
			animationId == ABHAnimations.RHandChargeThrow.AnimationId or 
			animationId == ABHAnimations.LHandChargeThrow.AnimationId or 
			animationId == ABHAnimations.SwitchHands.AnimationId or 
			animationId == ABHAnimations.KeeperAnimation.AnimationId
		then
			return true
		end
	end
	
	return false
end

--// ============================================================================
--// SETOR: HANDLER DE BOLA
--// ============================================================================

--- Callback quando bola é adicionada ao jogo
local function onBallAdded(ABHBall: SharedTypes.ABHBallInstance)
	local changedOwnershipMaid = Maid.new()
	local jumpMaid = Maid.new()
	local currentPlayerOnBall = ABHBall:WaitForChild("Information"):FindFirstChild("CurrentPlayerOnBall")

	--- Gerencia animação de bounce
	local function handleBallAnimation()
		if not currentPlayerOnBall then return end

		local ballOwner = currentPlayerOnBall.Value :: Player
		if not ballOwner then return end

		local character = ballOwner.Character :: Model
		if not character then return end

		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		local animator = humanoid:WaitForChild("Animator") :: Animator
		local holdBallAnimationTrack: AnimationTrack?

		local tweenInfo = TweenInfo.new(BOUNCE_COOLDOWN)
		local ballMotor6D = character:WaitForChild("BallOwnership", 5) :: Motor6D
		if not ballMotor6D then return end

		local originalC0 = ballMotor6D.C0

		--- Loop de bounce
		local isBouncing = false
		local function runBounceCycle()
			if isBouncing then return end
			isBouncing = true

			while currentPlayerOnBall.Value == ballOwner and ABHBall:IsDescendantOf(workspace) do
				-- Para de quicar durante charge/throw
				if isChargingAnimationPlaying(animator) then
					ballMotor6D.C0 = originalC0
					task.wait(0.1)
					continue
				end

				-- Toca animação de hold
				if not holdBallAnimationTrack or not holdBallAnimationTrack.IsPlaying then
					holdBallAnimationTrack = animator:LoadAnimation(ABHAnimations.HoldBall)
					holdBallAnimationTrack:Play()
				end

				-- Bounce para baixo (para o chão)
				local limit = ABHBall.Size.Y * 1.5
				local bounceToFieldTween = TweenService:Create(ballMotor6D, tweenInfo, {C0 = CFrame.new(originalC0.X, originalC0.Y, limit)})
				bounceToFieldTween:Play()

				-- Aguarda com verificação de posse
				local start = tick()
				while tick() - start < BOUNCE_COOLDOWN and currentPlayerOnBall.Value == ballOwner do
					task.wait(0.05)
				end
				if currentPlayerOnBall.Value ~= ballOwner then break end

				-- Bounce para cima (para a mão)
				local bounceToHandTween = TweenService:Create(ballMotor6D, tweenInfo, {C0 = originalC0})
				bounceToHandTween:Play()

				start = tick()
				while tick() - start < BOUNCE_COOLDOWN and currentPlayerOnBall.Value == ballOwner do
					task.wait(0.05)
				end
				if currentPlayerOnBall.Value ~= ballOwner then break end
			end
			
			isBouncing = false

			-- Cleanup
			if holdBallAnimationTrack then
				holdBallAnimationTrack:Stop(0.1)
				holdBallAnimationTrack = nil
			end
			if ballMotor6D and character and character.Parent then
				ballMotor6D.C0 = originalC0
			end
		end

		coroutine.wrap(runBounceCycle)()

		jumpMaid:GiveTask(function()
			if holdBallAnimationTrack then 
				holdBallAnimationTrack:Stop(0) 
				holdBallAnimationTrack = nil
			end
			if ballMotor6D and character and character.Parent then
				ballMotor6D.C0 = originalC0
			end
		end)
	end

	-- Inicia animação se já tem dono
	if currentPlayerOnBall and currentPlayerOnBall.Value then
		coroutine.wrap(handleBallAnimation)()
	end

	-- Monitora mudança de posse
	if currentPlayerOnBall then
		changedOwnershipMaid:GiveTask(currentPlayerOnBall:GetPropertyChangedSignal("Value"):Connect(function()
			jumpMaid:DoCleaning()

			if currentPlayerOnBall.Value then
				coroutine.wrap(handleBallAnimation)()
			end
		end))
	end

	-- Cleanup quando bola é destruída
	ABHBall.Destroying:Connect(function()
		changedOwnershipMaid:DoCleaning()
		jumpMaid:DoCleaning()
	end)
end

--// ============================================================================
--// SETOR: INICIALIZAÇÃO
--// ============================================================================

-- Bolas existentes
for _, ball in BALLS_FOLDER:GetChildren() do
	coroutine.wrap(onBallAdded)(ball :: SharedTypes.ABHBallInstance)
end

-- Novas bolas
BALLS_FOLDER.ChildAdded:Connect(function(ball)
	coroutine.wrap(onBallAdded)(ball :: SharedTypes.ABHBallInstance)
end)

--// ============================================================================
--// SETOR: HANDLERS DE PAUSE
--// ============================================================================

--- Para animações quando partida é pausada
REFEREE_EVENT_REMOTE.OnClientEvent:Connect(function(eventData)
	if eventData and eventData.action == "BALL_DROPPED_PAUSE" then
		local character = localPlayer.Character
		if not character then return end
		
		local humanoid = character:FindFirstChild("Humanoid")
		if not humanoid then return end
		
		local animator = humanoid:FindFirstChild("Animator")
		if not animator then return end
		
		-- Para animação HoldBall
		local playingTracks = animator:GetPlayingAnimationTracks()
		for _, track: AnimationTrack in playingTracks do
			if track.Animation and track.Animation.AnimationId == ABHAnimations.HoldBall.AnimationId then
				track:Stop(0)
				track:Destroy()
			end
		end
	end
end)

return {}
