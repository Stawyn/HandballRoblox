--[[
	================================================================================
	MÓDULO: SpawnTool
	================================================================================
	
	Descrição:
		Ferramenta básica para spawnar (criar) bolas no campo e removê-las.
		Geralmente utilizada para testes ou controle rápido.
	
	Dependências:
		- ClientNetwork (Comunicação com servidor)
		- Maid (Gerenciamento de limpeza de memória)
		- InputSystem (Entrada de comandos)
	
	Autor: Sistema ABH
	================================================================================
]]

--// ============================================================================
--// SETOR: Serviços
--// ============================================================================

local UserInputService = game:GetService("UserInputService")

--// ============================================================================
--// SETOR: Dependências
--// ============================================================================

local ClientNetwork = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Implementation"):WaitForChild("ClientNetwork"))
local Maid = require(game:GetService("ReplicatedStorage"):WaitForChild("Utilities"):WaitForChild("Maid"))
local InputSystem = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Implementation"):WaitForChild("InputSystem"))

local SpawnTool = {}

--// ============================================================================
--// SETOR: Inicialização
--// ============================================================================

--[[
	Inicializa a ferramenta quando ela é adicionada ao personagem.
	
	@param tool Tool - A instà¢ncia da ferramenta no jogo
]]
function SpawnTool:Initialize(tool: Tool)	
	local toolMaid = Maid.new()

	-- Conecta evento de equipar a ferramenta
	tool.Equipped:Connect(function()
		-- Habilita o contexto de input específico desta ferramenta
		InputSystem.Contexts["Spawn Tool"].Enabled = true

		-- Conecta ação de Spawn
		toolMaid:GiveTask(InputSystem.Actions["Spawn Tool"].Spawn.Pressed:Connect(function()
			ClientNetwork.BallEvents:SpawnRequest()
		end))

		-- Conecta ação de remover bolas
		toolMaid:GiveTask(InputSystem.Actions["Spawn Tool"]["Remove balls"].Pressed:Connect(function()
			ClientNetwork.BallEvents:ClearRequest()
		end))
	end)

	-- Conecta evento de desequipar
	tool.Unequipped:Connect(function()
		-- Desabilita contexto e limpa conexões
		InputSystem.Contexts["Spawn Tool"].Enabled = false
		toolMaid:DoCleaning()
	end)

	-- Limpeza total ao destruir
	tool.Destroying:Connect(function()
		toolMaid:DoCleaning()
	end)
end

return SpawnTool

