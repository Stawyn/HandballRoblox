--[[
    ================================================================================
    MÓDULO: ToolsController
    ================================================================================
    Descrição: Controlador central de ferramentas do cliente.
               Inicializa automaticamente cada ferramenta quando adicionada.
    
    Ferramentas Suportadas:
        - SpawnTool: Spawn de bola
        - ThrowTool: Arremesso e tackle
        - KeeperTool: Modo goleiro
        - RefSpawnTool: Spawn de árbitro
        - PenaltySpawnTool: Spawn de pênalti
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: SERVIÇOS E DEPENDÊNCIAS
--// ============================================================================

local Players = game:GetService("Players")

local SpawnTool = require("@self/SpawnTool")
local ThrowTool = require("@self/ThrowTool")
local KeeperTool = require("@self/KeeperTool")
local RefSpawnTool = require("@self/RefSpawnTool")
local PenaltySpawnTool = require("@self/PenaltySpawnTool")

--// ============================================================================
--// SETOR: REFERÊNCIAS E ESTADO
--// ============================================================================

local localPlayer = Players.LocalPlayer :: Player
local initializedTools: { [Tool]: boolean } = {}

--// ============================================================================
--// SETOR: MAPEAMENTO DE FERRAMENTAS
--// ============================================================================

local TOOL_MAP = {
	SpawnTool = SpawnTool,
	ThrowTool = ThrowTool,
	KeeperTool = KeeperTool,
	RefSpawnTool = RefSpawnTool,
	PenaltySpawnTool = PenaltySpawnTool,
}

--// ============================================================================
--// SETOR: FUNÇÕES
--// ============================================================================

--- Inicializa uma ferramenta
local function initTool(tool: Tool) 
	if initializedTools[tool] then return end

	local controller = TOOL_MAP[tool.Name]
	if controller then
		controller:Initialize(tool)
		initializedTools[tool] = true
	end
end

--- Callback quando personagem é adicionado
local function onCharacterAdded(character: Model)
	local backpack = localPlayer:WaitForChild("Backpack") :: Backpack
	
	-- Inicializa ferramentas existentes
	for _, tool in backpack:GetChildren() do
		if tool:IsA("Tool") then
			coroutine.wrap(initTool)(tool)
		end
	end
	
	for _, tool in character:GetChildren() do
		if tool:IsA("Tool") then
			coroutine.wrap(initTool)(tool)
		end
	end
	
	-- Conecta para novas ferramentas
	backpack.ChildAdded:Connect(function(tool)
		if tool:IsA("Tool") then
			coroutine.wrap(initTool)(tool)
		end
	end)
	
	character.ChildAdded:Connect(function(tool)
		if tool:IsA("Tool") then
			coroutine.wrap(initTool)(tool)
		end
	end)
end

--// ============================================================================
--// SETOR: INICIALIZAÇÃO
--// ============================================================================

local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
onCharacterAdded(character)
localPlayer.CharacterAdded:Connect(onCharacterAdded)

return {}