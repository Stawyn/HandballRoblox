--[[
    ================================================================================
    MÓDULO: Math
    ================================================================================
    Descrição: Funções matemáticas auxiliares para cálculos do jogo.
    
    Funções:
        - CheckApproxEqual: Verifica igualdade aproximada (epsilon 1e-6)
        - TernarySearch: Busca ternária para otimização de funções
    
    Autor: Sistema ABH
    ================================================================================
]]

local Math = {}

--// ============================================================================
--// SETOR: FUNÇÕES DE COMPARAÇÃO
--// ============================================================================

--- Verifica se dois números são aproximadamente iguais
-- @param approx number - Valor aproximado
-- @param target number - Valor alvo
-- @return boolean - true se diferença < 1e-6
function Math:CheckApproxEqual(approx: number, target: number): boolean
	return math.abs(approx - target) < 1e-6
end

--// ============================================================================
--// SETOR: FUNÇÕES DE OTIMIZAÇÃO
--// ============================================================================

--- Busca ternária para encontrar máximo de função unimodal
-- @param f function - Função a otimizar f(x) -> number
-- @param left number - Limite esquerdo do intervalo
-- @param right number - Limite direito do intervalo
-- @return number - Valor de x que maximiza f(x)
function Math:TernarySearch(f: (number) -> number, left: number, right: number): number
	local iterations = 20
	
	for i = 1, iterations do
		local leftThird = left + (right - left) / 3
		local rightThird = right - (right - left) / 3
		
		if f(leftThird) < f(rightThird) then
			right = rightThird
		else
			left = leftThird
		end
	end
	
	return (left + right) / 2
end

return Math