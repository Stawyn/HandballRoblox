--[[
    ================================================================================
    MÓDULO: SpawnTool
    ================================================================================
    Descrição: Controlador da ferramenta de spawn de bola.
               Permite spawnar e remover bolas do jogo.
    
    Funcionalidades:
        - Spawn de bola (input "Spawn")
        - Remover todas as bolas (input "Remove balls")
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: SERVIÇOS E DEPENDÊNCIAS
--// ============================================================================

local UserInputService = game:GetService("UserInputService")

local ClientNetwork = require("../../Implementation/ClientNetwork")
local Maid = require("../../../Utilities/Maid")
local InputSystem = require("../../Implementation/InputSystem")

--// ============================================================================
--// SETOR: MÓDULO
--// ============================================================================

local SpawnTool = {}

--// ============================================================================
--// SETOR: INICIALIZAÇÃO
--// ============================================================================

--- Inicializa a ferramenta de spawn
function SpawnTool:Initialize(tool: Tool)	
	local toolMaid = Maid.new()
	
	tool.Equipped:Connect(function()
		InputSystem.Contexts["Spawn Tool"].Enabled = true
		
		-- Spawn
		toolMaid:GiveTask(InputSystem.Actions["Spawn Tool"].Spawn.Pressed:Connect(function()
			ClientNetwork.BallEvents:SpawnRequest()
		end))
		
		-- Remove balls
		toolMaid:GiveTask(InputSystem.Actions["Spawn Tool"]["Remove balls"].Pressed:Connect(function()
			ClientNetwork.BallEvents:ClearRequest()
		end))
	end)
	
	tool.Unequipped:Connect(function()
		InputSystem.Contexts["Spawn Tool"].Enabled = false
		toolMaid:DoCleaning()
	end)
	
	tool.Destroying:Connect(function()
		toolMaid:DoCleaning()
	end)
end

return SpawnTool