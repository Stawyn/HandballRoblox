--[[
    ================================================================================
    MÓDULO: Utils
    ================================================================================
    Descrição: Utilitários gerais compartilhados para o jogo ABH Handball.
    
    Funcionalidades:
        - MergeTables: Combina duas tabelas em uma nova
        - CountOpponentsInRadius: Conta oponentes em um raio (DEPRECATED: use TeamUtils)
        - IsPointInHomeArea: Verifica se ponto está na área Home
        - IsPointInAwayArea: Verifica se ponto está na área Away
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: SERVIÇOS E DEPENDÊNCIAS
--// ============================================================================

local Utils = {}
local Teams = game:GetService("Teams")

--// ============================================================================
--// SETOR: FUNÇÕES DE TABELAS
--// ============================================================================

--- Mescla duas tabelas em uma nova tabela
-- @param t1 {T} - Primeira tabela
-- @param t2 {T} - Segunda tabela
-- @return {T} - Nova tabela com elementos de ambas
function Utils:MergeTables<T>(t1: { T }, t2: { T }): {T}
	local newTable = table.create(#t1 + #t2, nil)
	local currIndex = 1
	
	for i = 1, #t1 do
		newTable[currIndex] = t1[i]
		currIndex += 1
	end
	
	for i = 1, #t2 do
		newTable[currIndex] = t2[i]
		currIndex += 1
	end
	
	return newTable
end

--// ============================================================================
--// SETOR: FUNÇÕES DE CONTAGEM (DEPRECATED - Use TeamUtils)
--// ============================================================================

--- [DEPRECATED] Conta oponentes em um raio em torno de uma posição
-- NOTA: Use TeamUtils.countOpponentsInRadius em vez desta função
-- @param blacklistPlayer Player - Jogador a ignorar
-- @param center Vector3 - Centro da busca
-- @return number - Quantidade de oponentes no raio (-1 se erro)
function Utils:CountOpponentsInRadius(blacklistPlayer: Player, center: Vector3)
	local r = 14
	local radiusSquared = 10*10
	local count = 0

	local presumedTeam = blacklistPlayer.Team.Name :: string
	local opponents = {}
	if presumedTeam:find("Home") then
		opponents = Utils:MergeTables(Teams["Away Team"]:GetPlayers(), Teams["-Away Goalkeeper"]:GetPlayers())
	elseif presumedTeam:find("Away") then
		opponents = Utils:MergeTables(Teams["Home Team"]:GetPlayers(), Teams["-Home Goalkeeper"]:GetPlayers())
	else
		return -1
	end

	for _, player in opponents do
		if player == blacklistPlayer then
			continue
		end
		local character = player.Character
		if character then
			local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if humanoidRootPart then
				local offset = humanoidRootPart.Position - center
				local distanceSquared = offset:Dot(offset)

				if distanceSquared <= radiusSquared then
					count += 1
				end
			end
		end
	end

	return count
end

--// ============================================================================
--// SETOR: FUNÇÕES DE ÁREA DO CAMPO
--// ============================================================================

--- Verifica se um ponto está dentro da área do gol Home
-- @param point Vector3 - Posição a verificar
-- @return boolean - true se estiver na área Home
function Utils:IsPointInHomeArea(point: Vector3): boolean
	local centerX = -139.469
	local radius = 100
	local minX = -149.469

	local a, c = point.X, point.Z

	if a < minX then
		return false
	end

	local distX = a - centerX
	local distZ = c
	local distance = math.sqrt(distX * distX + distZ * distZ)

	return distance <= radius
end

--- Verifica se um ponto está dentro da área do gol Away
-- @param point Vector3 - Posição a verificar
-- @return boolean - true se estiver na área Away
function Utils:IsPointInAwayArea(point: Vector3): boolean
	local centerX = 139.469
	local radius = 100
	local maxX = 149.469

	local a, c = point.X, point.Z

	if a > maxX then
		return false
	end

	local distX = a - centerX
	local distZ = c
	local distance = math.sqrt(distX * distX + distZ * distZ)

	return distance <= radius
end


return Utils