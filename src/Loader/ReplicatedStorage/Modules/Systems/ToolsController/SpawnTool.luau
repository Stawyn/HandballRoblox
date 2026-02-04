--[[
	================================================================================
	MÃ“DULO: SpawnTool
	================================================================================
	
	DescriÃ§Ã£o:
		Ferramenta bÃ¡sica para spawnar (criar) bolas no campo e removÃª-las.
		Geralmente utilizada para testes ou controle rÃ¡pido.
	
	DependÃªncias:
		- ClientNetwork (ComunicaÃ§Ã£o com servidor)
		- Maid (Gerenciamento de limpeza de memÃ³ria)
		- InputSystem (Entrada de comandos)
	
	Autor: Sistema ABH
	================================================================================
]]

--// ============================================================================
--// SETOR: ServiÃ§os
--// ============================================================================

local UserInputService = game:GetService("UserInputService")

--// ============================================================================
--// SETOR: DependÃªncias
--// ============================================================================

local ClientNetwork = require("../../Implementation/ClientNetwork")
local Maid = require("../../../Utilities/Maid")
local InputSystem = require("../../Implementation/InputSystem")

local SpawnTool = {}

--// ============================================================================
--// SETOR: InicializaÃ§Ã£o
--// ============================================================================

--[[
	Inicializa a ferramenta quando ela Ã© adicionada ao personagem.
	
	@param tool Tool - A instÃ¢ncia da ferramenta no jogo
]]
function SpawnTool:Initialize(tool: Tool)	
	local toolMaid = Maid.new()

	-- Conecta evento de equipar a ferramenta
	tool.Equipped:Connect(function()
		-- Habilita o contexto de input especÃ­fico desta ferramenta
		InputSystem.Contexts["Spawn Tool"].Enabled = true

		-- Conecta aÃ§Ã£o de Spawn
		toolMaid:GiveTask(InputSystem.Actions["Spawn Tool"].Spawn.Pressed:Connect(function()
			ClientNetwork.BallEvents:SpawnRequest()
		end))

		-- Conecta aÃ§Ã£o de remover bolas
		toolMaid:GiveTask(InputSystem.Actions["Spawn Tool"]["Remove balls"].Pressed:Connect(function()
			ClientNetwork.BallEvents:ClearRequest()
		end))
	end)

	-- Conecta evento de desequipar
	tool.Unequipped:Connect(function()
		-- Desabilita contexto e limpa conexÃµes
		InputSystem.Contexts["Spawn Tool"].Enabled = false
		toolMaid:DoCleaning()
	end)

	-- Limpeza total ao destruir
	tool.Destroying:Connect(function()
		toolMaid:DoCleaning()
	end)
end

return SpawnTool

