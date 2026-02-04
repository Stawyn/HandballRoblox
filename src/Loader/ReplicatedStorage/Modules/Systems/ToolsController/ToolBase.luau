--[[
	================================================================================
	MÓDULO: ToolBase
	================================================================================
	
	Descrição:
		Classe base para todas as ferramentas do jogo.
		Fornece estrutura padronizada para Equipped, Unequipped e Destroying.
		Usa Janitor para gerenciamento automático de limpeza.
	
	Uso:
		local ToolBase = require(path.to.ToolBase)
		
		local MinhaTool = {}
		setmetatable(MinhaTool, {__index = ToolBase})
		
		function MinhaTool:aoEquipar()
			-- Lógica de equipar
		end
	
	Autor: Sistema ABH
	================================================================================
]]

local ToolBase = {}
ToolBase.__index = ToolBase

--// ============================================================================
--// SETOR: Serviços
--// ============================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// ============================================================================
--// SETOR: Dependências
--// ============================================================================

local Utilities = ReplicatedStorage:WaitForChild("Utilities")
local Janitor = require(Utilities:WaitForChild("Janitor"))

--// ============================================================================
--// SETOR: Construtor
--// ============================================================================

--[[
	Cria uma nova instà¢ncia de ToolBase.
	
	@return ToolBase - Nova instà¢ncia
]]
function ToolBase.new()
	local self = setmetatable({}, ToolBase)
	self._janitor = Janitor.new()
	self._equipadoJanitor = Janitor.new()
	self._ferramenta = nil :: Tool?
	return self
end

--// ============================================================================
--// SETOR: Métodos Virtuais (para sobrescrever)
--// ============================================================================

--[[
	Chamado quando a ferramenta é equipada.
	Sobrescreva este método na sua ferramenta.
	
	@param ferramenta Tool - A ferramenta que foi equipada
]]
function ToolBase:aoEquipar(ferramenta: Tool)
	-- Sobrescrever na subclasse
end

--[[
	Chamado quando a ferramenta é desequipada.
	Sobrescreva este método na sua ferramenta.
]]
function ToolBase:aoDesequipar()
	-- Sobrescrever na subclasse
end

--[[
	Chamado quando a ferramenta está sendo destruída.
	Sobrescreva este método na sua ferramenta.
]]
function ToolBase:aoDestruir()
	-- Sobrescrever na subclasse
end

--// ============================================================================
--// SETOR: Gerenciamento de Tarefas
--// ============================================================================

--[[
	Adiciona uma tarefa ao janitor que será limpa ao desequipar.
	Use para conexões e objetos temporários durante uso da ferramenta.
	
	@param tarefa any - Tarefa a ser adicionada (conexào, função, etc.)
	@param metodoLimpeza string? - Método de limpeza opcional ("Disconnect", "Destroy", etc.)
]]
function ToolBase:adicionarTarefa(tarefa: any, metodoLimpeza: string?)
	if metodoLimpeza then
		self._equipadoJanitor:Add(tarefa, metodoLimpeza)
	else
		self._equipadoJanitor:Add(tarefa)
	end
end

--[[
	Adiciona uma tarefa permanente que só será limpa ao destruir a ferramenta.
	
	@param tarefa any - Tarefa a ser adicionada
	@param metodoLimpeza string? - Método de limpeza opcional
]]
function ToolBase:adicionarTarefaPermanente(tarefa: any, metodoLimpeza: string?)
	if metodoLimpeza then
		self._janitor:Add(tarefa, metodoLimpeza)
	else
		self._janitor:Add(tarefa)
	end
end

--// ============================================================================
--// SETOR: Inicialização
--// ============================================================================

--[[
	Inicializa a ferramenta com os eventos padrào.
	Deve ser chamado pela subclasse após a criação.
	
	@param ferramenta Tool - A instà¢ncia da ferramenta
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
--// SETOR: Utilitários
--// ============================================================================

--[[
	Retorna a ferramenta associada.
	
	@return Tool? - A ferramenta ou nil se não inicializada
]]
function ToolBase:obterFerramenta(): Tool?
	return self._ferramenta
end

return ToolBase

