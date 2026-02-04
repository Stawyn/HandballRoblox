--[[
	================================================================================
	MÃ“DULO: Vector
	================================================================================
	
	DescriÃ§Ã£o:
		UtilitÃ¡rios para conversÃ£o entre tipos de vetor.
		Converte entre Vector3 (Roblox) e vector (biblioteca nativa de Luau).
	
	Nota:
		O tipo 'vector' Ã© o tipo nativo de Luau, diferente de Vector3.
		Use essas funÃ§Ãµes quando precisar trabalhar com ambos os tipos.
	
	Autor: Sistema ABH
	================================================================================
]]

local Vector = {}

--// ============================================================================
--// SETOR: ConversÃµes de Vetor
--// ============================================================================

--[[
	Converte um Vector3 (Roblox) para vector (Luau nativo).
	
	@param v Vector3 - O vetor Roblox a ser convertido
	@return vector - O vetor nativo resultante
	
	Exemplo:
		local vetorNativo = Vector:Vector3ToVectorLib(Vector3.new(1, 2, 3))
]]
function Vector:Vector3ToVectorLib(v: Vector3): vector
	return vector.create(v.X, v.Y, v.Z)
end

--[[
	Converte um vector (Luau nativo) para Vector3 (Roblox).
	
	@param v vector - O vetor nativo a ser convertido
	@return Vector3 - O vetor Roblox resultante
	
	Exemplo:
		local vetorRoblox = Vector:VectorLibToVector3(vector.create(1, 2, 3))
]]
function Vector:VectorLibToVector3(v: vector): Vector3
	return Vector3.new(v.x, v.y, v.z)
end

return Vector

