--[[
	================================================================================
	MÓDULO: UIColors
	================================================================================
	
	Descrição:
		Centraliza todas as constantes de cores utilizadas nas interfaces do jogo.
		Evita duplicação de definição de cores em múltiplos módulos.
	
	Uso:
		local UIColors = require(path.to.UIColors)
		local cor = UIColors.obterCorPorPorcentagem(0.8) -- Retorna verde
	
	Autor: Sistema ABH
	================================================================================
]]

--// ============================================================================
--// SETOR: Definições de Cores
--// ============================================================================

local UIColors = {}

--- Cores padrào para barras de progresso (Stamina, Poder, etc.)
UIColors.Progresso = {
	CHEIO = Color3.fromRGB(46, 204, 113),      -- Verde moderno
	MEDIO = Color3.fromRGB(241, 196, 15),      -- Amarelo moderno
	CRITICO = Color3.fromRGB(231, 76, 60),     -- Vermelho moderno
}

--- Cores para indicadores de ganho/perda
UIColors.Indicador = {
	GANHO = Color3.fromRGB(46, 204, 113),      -- Verde (positivo)
	PERDA = Color3.fromRGB(192, 57, 43),       -- Vermelho escuro (negativo)
}

--- Cores para times
UIColors.Time = {
	HOME = Color3.fromRGB(0, 0, 255),          -- Azul
	AWAY = Color3.fromRGB(255, 0, 0),          -- Vermelho
}

--- Cores para cartões
UIColors.Cartao = {
	AMARELO = Color3.fromRGB(255, 255, 0),
	VERMELHO = Color3.fromRGB(255, 0, 0),
}

--// ============================================================================
--// SETOR: Funções Utilitárias
--// ============================================================================

--[[
	Obtém a cor apropriada baseada em uma porcentagem (0 a 1).
	
	@param porcentagem number - Valor entre 0 e 1
	@return Color3 - Cor correspondente ao nível
	
	Exemplo:
		obterCorPorPorcentagem(0.8) -> Verde (CHEIO)
		obterCorPorPorcentagem(0.4) -> Amarelo (MEDIO)
		obterCorPorPorcentagem(0.2) -> Vermelho (CRITICO)
]]
function UIColors.obterCorPorPorcentagem(porcentagem: number): Color3
	if porcentagem > 0.6 then
		return UIColors.Progresso.CHEIO
	elseif porcentagem > 0.25 then
		return UIColors.Progresso.MEDIO
	else
		return UIColors.Progresso.CRITICO
	end
end

--[[
	Obtém a cor de time baseada em se é Home ou Away.
	
	@param ehHome boolean - True para time da casa, false para visitante
	@return Color3 - Cor do time
]]
function UIColors.obterCorTime(ehHome: boolean): Color3
	return if ehHome then UIColors.Time.HOME else UIColors.Time.AWAY
end

return UIColors

