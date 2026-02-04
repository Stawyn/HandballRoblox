--[[
	================================================================================
	MÃ“DULO: ToolBase
	================================================================================
	
	DescriÃ§Ã£o:
		Classe base para todas as ferramentas do jogo.
		Fornece estrutura padronizada para Equipped, Unequipped e Destroying.
		Usa Janitor para gerenciamento automÃ¡tico de limpeza.
	
	Uso:
		local ToolBase = require(path.to.ToolBase)
		
		local MinhaTool = {}
		setmetatable(MinhaTool, {__index = ToolBase})
		
		function MinhaTool:aoEquipar()
			-- LÃ³gica de equipar
		end
	
	Autor: Sistema ABH
	================================================================================
]]

local ToolBase = {}
ToolBase.__index = ToolBase

--// ============================================================================
--// SETOR: ServiÃ§os
--// ============================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// ============================================================================
--// SETOR: DependÃªncias
--// ============================================================================

local Utilities = ReplicatedStorage:WaitForChild("Utilities")
local Janitor = require(Utilities:WaitForChild("Janitor"))

--// ============================================================================
--// SETOR: Construtor
--// ============================================================================

--[[
	Cria uma nova instÃ¢ncia de ToolBase.
	
	@return ToolBase - Nova instÃ¢ncia
]]
function ToolBase.new()
	local self = setmetatable({}, ToolBase)
	self._janitor = Janitor.new()
	self._equipadoJanitor = Janitor.new()
	self._ferramenta = nil :: Tool?
	return self
end

--// ============================================================================
--// SETOR: MÃ©todos Virtuais (para sobrescrever)
--// ============================================================================

--[[
	Chamado quando a ferramenta Ã© equipada.
	Sobrescreva este mÃ©todo na sua ferramenta.
	
	@param ferramenta Tool - A ferramenta que foi equipada
]]
function ToolBase:aoEquipar(ferramenta: Tool)
	-- Sobrescrever na subclasse
end

--[[
	Chamado quando a ferramenta Ã© desequipada.
	Sobrescreva este mÃ©todo na sua ferramenta.
]]
function ToolBase:aoDesequipar()
	-- Sobrescrever na subclasse
end

--[[
	Chamado quando a ferramenta estÃ¡ sendo destruÃ­da.
	Sobrescreva este mÃ©todo na sua ferramenta.
]]
function ToolBase:aoDestruir()
	-- Sobrescrever na subclasse
end

--// ============================================================================
--// SETOR: Gerenciamento de Tarefas
--// ============================================================================

--[[
	Adiciona uma tarefa ao janitor que serÃ¡ limpa ao desequipar.
	Use para conexÃµes e objetos temporÃ¡rios durante uso da ferramenta.
	
	@param tarefa any - Tarefa a ser adicionada (conexÃ£o, funÃ§Ã£o, etc.)
	@param metodoLimpeza string? - MÃ©todo de limpeza opcional ("Disconnect", "Destroy", etc.)
]]
function ToolBase:adicionarTarefa(tarefa: any, metodoLimpeza: string?)
	if metodoLimpeza then
		self._equipadoJanitor:Add(tarefa, metodoLimpeza)
	else
		self._equipadoJanitor:Add(tarefa)
	end
end

--[[
	Adiciona uma tarefa permanente que sÃ³ serÃ¡ limpa ao destruir a ferramenta.
	
	@param tarefa any - Tarefa a ser adicionada
	@param metodoLimpeza string? - MÃ©todo de limpeza opcional
]]
function ToolBase:adicionarTarefaPermanente(tarefa: any, metodoLimpeza: string?)
	if metodoLimpeza then
		self._janitor:Add(tarefa, metodoLimpeza)
	else
		self._janitor:Add(tarefa)
	end
end

--// ============================================================================
--// SETOR: InicializaÃ§Ã£o
--// ============================================================================

--[[
	Inicializa a ferramenta com os eventos padrÃ£o.
	Deve ser chamado pela subclasse apÃ³s a criaÃ§Ã£o.
	
	@param ferramenta Tool - A instÃ¢ncia da ferramenta
]]
function ToolBase:inicializar(ferramenta: Tool)
	self._ferramenta = ferramenta

	-- Conecta eventos da ferramenta
	self._janitor:Add(ferramenta.Equipped:Connect(function()
		self:_onEquipped()
	end), "Disconnect")

	self._janitor:Add(ferramenta.Unequipped:Connect(function()
		self:_onUnequipped()
	end), "Disconnect")

	self._janitor:Add(ferramenta.Destroying:Connect(function()
		self:_onDestroying()
	end), "Disconnect")
end

--// ============================================================================
--// SETOR: Handlers Internos
--// ============================================================================

function ToolBase:_onEquipped()
	self:aoEquipar(self._ferramenta)
end

function ToolBase:_onUnequipped()
	self._equipadoJanitor:Cleanup()
	self:aoDesequipar()
end

function ToolBase:_onDestroying()
	self:aoDestruir()
	self._equipadoJanitor:Destroy()
	self._janitor:Destroy()
end

--// ============================================================================
--// SETOR: UtilitÃ¡rios
--// ============================================================================

--[[
	Retorna a ferramenta associada.
	
	@return Tool? - A ferramenta ou nil se nÃ£o inicializada
]]
function ToolBase:obterFerramenta(): Tool?
	return self._ferramenta
end

return ToolBase

