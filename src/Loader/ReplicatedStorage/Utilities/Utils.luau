--[[
	================================================================================
	MÓDULO: Utils
	================================================================================
	
	Descrição:
		Funções utilitárias compartilhadas entre cliente e servidor.
		Contém helpers para manipulação de tabelas, validação de personagens
		e cálculos de proximidade de jogadores.
	
	Autor: Sistema ABH
	================================================================================
]]

local Utils = {}

--// ============================================================================
--// SETOR: Serviços
--// ============================================================================

local Teams = game:GetService("Teams")

--// ============================================================================
--// SETOR: Manipulação de Tabelas
--// ============================================================================

--[[
	Combina duas tabelas em uma nova tabela.
	não modifica as tabelas originais.
	
	@param tabela1 {T} - Primeira tabela a ser combinada
	@param tabela2 {T} - Segunda tabela a ser combinada
	@return {T} - Nova tabela com todos os elementos de ambas
	
	Exemplo:
		local combinada = Utils:MergeTables({1, 2}, {3, 4}) -- {1, 2, 3, 4}
]]
function Utils:MergeTables<T>(tabela1: { T }, tabela2: { T }): {T}
	local novaTabela = table.create(#tabela1 + #tabela2, nil)
	local indiceAtual = 1

	for i = 1, #tabela1 do
		novaTabela[indiceAtual] = tabela1[i]
		indiceAtual += 1
	end

	for i = 1, #tabela2 do
		novaTabela[indiceAtual] = tabela2[i]
		indiceAtual += 1
	end

	return novaTabela
end

--// ============================================================================
--// SETOR: Validação de Personagem
--// ============================================================================

--[[
	Valida se um jogador possui um personagem válido com HumanoidRootPart.
	
	@param jogador Player - O jogador a ser validado
	@return (Model?, BasePart?) - Personagem e HumanoidRootPart, ou nil se inválido
	
	Exemplo:
		local personagem, hrp = Utils:ValidarPersonagem(jogador)
		if not personagem then return end
]]
function Utils:ValidarPersonagem(jogador: Player): (Model?, BasePart?)
	local personagem = jogador.Character
	if not personagem then
		return nil, nil
	end

	local humanoidRootPart = personagem:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoidRootPart then
		return personagem, nil
	end

	return personagem, humanoidRootPart
end

--[[
	Valida se um personagem possui um Humanoid válido e vivo.
	
	@param personagem Model - O modelo do personagem
	@return Humanoid? - O Humanoid se válido e vivo, nil caso contrário
]]
function Utils:ValidarHumanoid(personagem: Model): Humanoid?
	local humanoid = personagem:FindFirstChild("Humanoid") :: Humanoid?
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return humanoid
end

--// ============================================================================
--// SETOR: Cálculos de Proximidade
--// ============================================================================

--- Constantes para cálculo de proximidade
local RAIO_DETECCAO = 10
local RAIO_DETECCAO_QUADRADO = RAIO_DETECCAO * RAIO_DETECCAO

--[[
	Conta quantos oponentes estào dentro de um raio específico.
	Usado para calcular modificadores de poder de arremesso.
	
	@param jogadorExcluido Player - Jogador que não deve ser contado
	@param centro Vector3 - Posição central para verificar
	@return number - Quantidade de oponentes no raio (-1 se time inválido)
	
	Nota: O raio de detecção é de 10 studs.
]]
function Utils:ContarOponentesNoRaio(jogadorExcluido: Player, centro: Vector3): number
	local contagem = 0

	-- Determina o time do jogador e obtém os oponentes
	local nomeTime = jogadorExcluido.Team.Name :: string
	local oponentes = {}

	if nomeTime:find("Home") then
		oponentes = Utils:MergeTables(
			Teams["Away Team"]:GetPlayers(), 
			Teams["-Away Goalkeeper"]:GetPlayers()
		)
	elseif nomeTime:find("Away") then
		oponentes = Utils:MergeTables(
			Teams["Home Team"]:GetPlayers(), 
			Teams["-Home Goalkeeper"]:GetPlayers()
		)
	else
		return -1 -- Time inválido (ex: Lobby, Officials)
	end

	-- Verifica cada oponente
	for _, jogador in oponentes do
		if jogador == jogadorExcluido then
			continue
		end

		local _, humanoidRootPart = Utils:ValidarPersonagem(jogador)
		if humanoidRootPart then
			local deslocamento = humanoidRootPart.Position - centro
			local distanciaQuadrada = deslocamento:Dot(deslocamento)

			if distanciaQuadrada <= RAIO_DETECCAO_QUADRADO then
				contagem += 1
			end
		end
	end

	return contagem
end

-- Alias para compatibilidade com código existente
Utils.CountOpponentsInRadius = Utils.ContarOponentesNoRaio

return Utils

