--[[
	================================================================================
	MÃ“DULO: SharedAttributes
	================================================================================
	
	DescriÃ§Ã£o:
		Centraliza valores de atributos compartilhados entre cliente e servidor.
		Define velocidades de movimento, limites de ping e outras constantes.
	
	Uso:
		local SharedAttributes = require(path.to.SharedAttributes)
		local velocidade = SharedAttributes:GetWalkSpeed()
	
	Autor: Sistema ABH
	================================================================================
]]

local SharedAttributes = {}

--// ============================================================================
--// SETOR: ServiÃ§os
--// ============================================================================

local StarterPlayer = game:GetService("StarterPlayer")

--// ============================================================================
--// SETOR: Constantes Base
--// ============================================================================

--- Velocidade base de caminhada (definida no StarterPlayer)
local VELOCIDADE_CAMINHADA = StarterPlayer.CharacterWalkSpeed

--- BÃ´nus de velocidade ao correr
local BONUS_CORRIDA = 7

--- Velocidades do goleiro
local VELOCIDADE_GOLEIRO = 10
local VELOCIDADE_GOLEIRO_FOCADO = 4

--- Constante de arrasto da bola
local CONSTANTE_ARRASTO = 0.7

--- Ping mÃ¡ximo permitido para interaÃ§Ãµes
local PING_MAXIMO = 350

--// ============================================================================
--// SETOR: Velocidades de Movimento
--// ============================================================================

--[[
	Retorna a velocidade de caminhada padrÃ£o.
	
	@return number - Velocidade de caminhada (studs/segundo)
]]
function SharedAttributes:GetWalkSpeed(): number
	return VELOCIDADE_CAMINHADA 
end

--[[
	Retorna a velocidade de corrida (sprint).
	
	@return number - Velocidade de corrida (studs/segundo)
]]
function SharedAttributes:GetSprintSpeed(): number
	return VELOCIDADE_CAMINHADA + BONUS_CORRIDA
end

--[[
	Retorna a velocidade padrÃ£o do goleiro.
	
	@return number - Velocidade do goleiro (studs/segundo)
]]
function SharedAttributes:GetGoalkeeperSpeed(): number
	return VELOCIDADE_GOLEIRO
end

--[[
	Retorna a velocidade do goleiro quando focado (segurando bola).
	
	@return number - Velocidade focada do goleiro (studs/segundo)
]]
function SharedAttributes:GetGoalkeeperFocusedSpeed(): number
	return VELOCIDADE_GOLEIRO_FOCADO
end

--// ============================================================================
--// SETOR: FÃ­sica
--// ============================================================================

--[[
	Retorna a constante de arrasto para fÃ­sica da bola.
	Usado para desacelerar a bola ao longo do tempo.
	
	@return number - Constante de arrasto (0-1)
]]
function SharedAttributes:GetKDrag(): number
	return CONSTANTE_ARRASTO
end

--// ============================================================================
--// SETOR: Rede
--// ============================================================================

--[[
	Retorna o ping mÃ¡ximo permitido para interaÃ§Ãµes.
	Jogadores com ping acima deste valor tÃªm interaÃ§Ãµes bloqueadas.
	
	@return number - Ping mÃ¡ximo em milissegundos
]]
function SharedAttributes:MaxPing(): number
	return PING_MAXIMO
end

return SharedAttributes

