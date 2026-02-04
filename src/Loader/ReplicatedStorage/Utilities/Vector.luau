--[[
    ================================================================================
    MÓDULO: Vector
    ================================================================================
    Descrição: Funções de conversão entre Vector3 (Roblox) e vector (nativo Luau).
    
    Funções:
        - Vector3ToVectorLib: Converte Vector3 para vector nativo
        - VectorLibToVector3: Converte vector nativo para Vector3
    
    Nota: O tipo 'vector' é o tipo nativo do Luau (vector.create),
          enquanto Vector3 é o tipo do Roblox com métodos adicionais.
    
    Autor: Sistema ABH
    ================================================================================
]]

local Vector = {}

--// ============================================================================
--// SETOR: CONVERSÕES
--// ============================================================================

--- Converte Vector3 (Roblox) para vector (Luau nativo)
-- @param v Vector3 - Vetor Roblox
-- @return vector - Vetor nativo Luau
function Vector:Vector3ToVectorLib(v: Vector3): vector
	return vector.create(v.X, v.Y, v.Z)
end

--- Converte vector (Luau nativo) para Vector3 (Roblox)
-- @param v vector - Vetor nativo Luau
-- @return Vector3 - Vetor Roblox
function Vector:VectorLibToVector3(v: vector): Vector3
	return Vector3.new(v.x, v.y, v.z)
end

return Vector