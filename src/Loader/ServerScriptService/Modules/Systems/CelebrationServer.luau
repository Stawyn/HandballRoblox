--[[
    ================================================================================
    MÓDULO: CelebrationServer
    ================================================================================
    Descrição: Gerencia a compra e reprodução de celebrações (emotes).
    Funcionalidades: - Compra de emotes com validação de moedas.
                     - Reprodução de animações no servidor (replicação).
    Autor: Sistema ABH
    ================================================================================
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PlayerModule = require(script.Parent.Player)

local EmotesSource = ReplicatedStorage:WaitForChild("EmotesSource")
local EmoteEvent = EmotesSource:WaitForChild("RE")
local AllEmotes = EmotesSource:WaitForChild("Emotes")

--// ============================================================================
--// SETOR: ESTADO
--// ============================================================================

-- Armazena o emote selecionado por jogador
local selectedEmotes: {[Player]: string} = {}

--// ============================================================================
--// SETOR: LOGICA
--// ============================================================================

local function handleEmoteEvent(player: Player, action: string, emoteName: string?)
	if action == "BUY" and emoteName then
		-- Ação: COMPRAR
		local emoteAsset = AllEmotes:FindFirstChild(emoteName)
		if not emoteAsset then return end
		
		local priceVal = emoteAsset:FindFirstChild("PRICE")
		if not priceVal then return end
		
		local price = priceVal.Value
		local leaderstats = player:FindFirstChild("leaderstats")
		if not leaderstats or not leaderstats:FindFirstChild("Coins") then return end
		
		local coins = leaderstats.Coins.Value
		
		if coins >= price then
			-- Verifica se já tem
			local userEmotes = player:FindFirstChild("Emotes")
			if userEmotes and userEmotes:FindFirstChild(emoteName) then
				return -- Já possui
			end
			
			-- Deduzir e adicionar
			PlayerModule:AddCoins(player, -price)
			PlayerModule:AddEmote(player, emoteName)
			
			print(player.Name .. " comprou emote " .. emoteName)
		end
		
	elseif action == "SELECT" and emoteName then
		-- Ação: SELECIONAR emote para uso com tecla B
		local userEmotes = player:FindFirstChild("Emotes")
		if userEmotes and userEmotes:FindFirstChild(emoteName) then
			selectedEmotes[player] = emoteName
			print(player.Name .. " selecionou emote: " .. emoteName)
		end
		
	elseif action == "PLAY" then
		-- Ação: REPRODUZIR emote selecionado (tecla B)
		local selectedEmote = selectedEmotes[player]
		if not selectedEmote then return end
		
		local userEmotes = player:FindFirstChild("Emotes")
		if not userEmotes or not userEmotes:FindFirstChild(selectedEmote) then return end
		
		local emoteAsset = AllEmotes:FindFirstChild(selectedEmote)
		if not emoteAsset then return end
		
		local character = player.Character
		if not character then return end
		
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end
		
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		
		-- Carrega e toca a animação (replica automaticamente para outros jogadores)
		local track = animator:LoadAnimation(emoteAsset)
		track:Play()
		
		print(player.Name .. " executou emote: " .. selectedEmote)
		
	elseif action == "GET_SELECTED" then
		-- Retorna o emote selecionado atual
		return selectedEmotes[player]
	end
end

EmoteEvent.OnServerEvent:Connect(handleEmoteEvent)

-- Limpar quando jogador sair
Players.PlayerRemoving:Connect(function(player)
	selectedEmotes[player] = nil
end)

return {}
