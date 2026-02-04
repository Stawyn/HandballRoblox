--[[
    ================================================================================
    MODULO: CardSystem
    ================================================================================
    Descricao: Sistema de cartoes do jogo ABH - gerencia cartoes amarelos
               e vermelhos com expulsao temporaria.
    
    Funcionalidades:
        - Cartao amarelo (YC): Aviso visual acima da cabeca
        - 2x YC = Cartao vermelho automatico
        - Cartao vermelho (RC): Expulsao por 120 segundos para o Lobby
        - Retorno automatico ao time original apos expulsao
        - ResetAll para limpar todos os cartoes
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: SERVICOS
--// ============================================================================

local Teams = game:GetService("Teams")

--// ============================================================================
--// SETOR: MODULO
--// ============================================================================

local cardSystem = {}
cardSystem.Players = {}

--// ============================================================================
--// SETOR: CONSTANTES
--// ============================================================================

local RED_CARD_DURATION = 120 -- segundos de expulsao
local YELLOW_COLOR = Color3.fromRGB(255, 255, 0)
local RED_COLOR = Color3.fromRGB(255, 0, 0)

--// ============================================================================
--// SETOR: FUNCOES INTERNAS
--// ============================================================================

--- Adiciona jogador ao sistema de cartoes se ainda nao existir
-- @param player Player - O jogador a adicionar
function cardSystem:AddPlayer(player)
	if not self.Players[player.UserId] then
		self.Players[player.UserId] = {
			player = player,
			hasYellow = false,
			hasRed = false,
			yellowCards = 0,
			redCardSeconds = 0,
			redFunction = nil,
			originalTeam = nil,
		}
	end
end

--- Obtem dados do jogador no sistema
-- @param player Player - O jogador
-- @return table? - Dados do jogador ou nil
function cardSystem:GetData(player)
	return self.Players[player.UserId]
end

--- Aplica GUI de cartao acima da cabeca do jogador
-- @param player Player - O jogador
-- @param text string - Texto a exibir
-- @param color3 Color3 - Cor do texto
function cardSystem:ApplyCardGui(player, text, color3)
	if not player.Character then return end

	local head = player.Character:FindFirstChild("Head")
	if not head then return end

	if not head:FindFirstChild("CardGui") then 
		local playerCardGui = script.CardGui:Clone()
		playerCardGui.Parent = head
		playerCardGui.TextLabel.Text = text
		playerCardGui.TextLabel.TextColor3 = color3
	else
		local playerCardGui = head.CardGui
		playerCardGui.TextLabel.Text = text
		playerCardGui.TextLabel.TextColor3 = color3
	end
end

--// ============================================================================
--// SETOR: FUNCOES PUBLICAS
--// ============================================================================

--- Remove todos os cartoes de um jogador
-- @param player Player - O jogador a limpar
function cardSystem:RemovePlayerCards(player)
	self:AddPlayer(player)

	local playerData = self.Players[player.UserId]

	playerData.hasRed = false
	playerData.hasYellow = false
	playerData.yellowCards = 0
	playerData.redCardSeconds = 0

	if not player.Character then return end

	local head = player.Character:FindFirstChild("Head")

	if head and head:FindFirstChild("CardGui") then
		head.CardGui:Destroy()
	end
end

--- Aplica cartao vermelho ao jogador
-- @param player Player - O jogador a receber o cartao
function cardSystem:GiveRed(player)
	self:AddPlayer(player)

	local playerData = self.Players[player.UserId]

	if playerData.hasRed then return end

	playerData.originalTeam = player.Team
	self:RemovePlayerCards(player)

	playerData.hasRed = true
	playerData.redCardSeconds = RED_CARD_DURATION
	player.Team = Teams.Lobby

	if playerData.redFunction then
		task.cancel(playerData.redFunction)
	end

	playerData.redFunction = task.spawn(function()

		while playerData.redCardSeconds > 0 and playerData.hasRed do
			task.wait(1)
			playerData.redCardSeconds -= 1

			self:ApplyCardGui(player, tostring(playerData.redCardSeconds), RED_COLOR)
		end

		local wasExpelled = playerData.hasRed
		playerData.hasRed = false
		playerData.redCardSeconds = 0

		-- Retorna o jogador para o time original e teletransporta para o meio
		if wasExpelled and playerData.originalTeam and playerData.originalTeam.Parent then
			player.Team = playerData.originalTeam
			task.defer(function()
				if player.Character then
					player.Character:PivotTo(CFrame.new(0, 5, 0)) -- Meio da quadra
				end
			end)
		end

		-- Remove o Gui + cartoes do jogador apos ter finalizado os 120 segundos
		self:RemovePlayerCards(player)
	end)
end

--- Aplica cartao amarelo ao jogador
-- @param player Player - O jogador a receber o cartao
function cardSystem:GiveYellow(player)
	self:AddPlayer(player)

	local playerData = self.Players[player.UserId]

	if playerData.hasRed then return end

	playerData.yellowCards += 1 
	playerData.hasYellow = true

	self:ApplyCardGui(player, "YC", YELLOW_COLOR)

	if playerData.yellowCards >= 2 then
		self:GiveRed(player)
	end
end

--- Reaplica GUI de cartao quando personagem respawna
-- @param player Player - O jogador
function cardSystem:OnCharacterAdded(player)
	self:AddPlayer(player)

	local playerData = self.Players[player.UserId]

	if playerData.hasRed and playerData.redCardSeconds > 0 then
		self:ApplyCardGui(player, tostring(playerData.redCardSeconds), RED_COLOR)

	elseif playerData.hasYellow then
		self:ApplyCardGui(player, "YC", YELLOW_COLOR)
	end
end

--- Reseta todos os cartoes de todos os jogadores
function cardSystem:ResetAll()
	for userId, playerData in self.Players do
		if playerData.redFunction then
			task.cancel(playerData.redFunction)
			playerData.redFunction = nil
		end

		local player = playerData.player
		if player and player.Parent then
			self:RemovePlayerCards(player)

			-- If player was in Lobby due to red card, return them
			if playerData.hasRed and playerData.originalTeam and playerData.originalTeam.Parent then
				player.Team = playerData.originalTeam
				task.defer(function()
					if player.Character then
						player.Character:PivotTo(CFrame.new(0, 5, 0)) -- Meio da quadra
					end
				end)
			end
		end
	end
	self.Players = {}
end

return cardSystem
