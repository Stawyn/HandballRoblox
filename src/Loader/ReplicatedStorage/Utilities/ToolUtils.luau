--[[
	================================================================================
	MÓDULO: ToolUtils (Utilitários de Ferramentas)
	================================================================================
	
	Descrição:
		Funções centralizadas para gerenciamento de ferramentas (Tools).
		Evita duplicação de código entre diferentes ferramentas do projeto.
	
	Funções:
		- isToolEquipped: Verifica se uma ferramenta está equipada
		- getEquippedTool: Retorna a ferramenta equipada ou nil
		- hasToolInBackpack: Verifica se tem ferramenta no Backpack
	
	Autor: Sistema ABH
	================================================================================
]]

--// ============================================================================
--// SETOR: Serviços do Roblox
--// ============================================================================

local Players = game:GetService("Players")

--// ============================================================================
--// SETOR: Definição do Módulo
--// ============================================================================

local ToolUtils = {}

--// ============================================================================
--// SETOR: Funções de Verificação
--// ============================================================================

--- Verifica se uma ferramenta específica está equipada pelo jogador
-- @param player Player - O jogador a verificar
-- @param toolName string - Nome da ferramenta
-- @return boolean - true se a ferramenta está equipada
function ToolUtils.isToolEquipped(player: Player, toolName: string): boolean
	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character

	if not character then
		return false
	end

	-- Verifica no Backpack (não equipada = está lá)
	if backpack and backpack:FindFirstChild(toolName) then
		return true
	end

	-- Verifica no Character (equipada = está no Character)
	if character:FindFirstChild(toolName) then
		return true
	end

	return false
end

--- Verifica se o jogador local tem uma ferramenta específica
-- Para uso em scripts cliente
-- @param toolName string - Nome da ferramenta
-- @return boolean - true se a ferramenta existe (equipada ou no backpack)
function ToolUtils.localPlayerHasTool(toolName: string): boolean
	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		return false
	end

	return ToolUtils.isToolEquipped(localPlayer, toolName)
end

--- Retorna a instà¢ncia da ferramenta se estiver equipada no Character
-- @param player Player - O jogador
-- @param toolName string - Nome da ferramenta
-- @return Tool? - A ferramenta ou nil
function ToolUtils.getEquippedTool(player: Player, toolName: string): Tool?
	local character = player.Character
	if not character then
		return nil
	end

	local tool = character:FindFirstChild(toolName)
	if tool and tool:IsA("Tool") then
		return tool :: Tool
	end

	return nil
end

--- Verifica se a ferramenta está no Backpack (não equipada)
-- @param player Player - O jogador
-- @param toolName string - Nome da ferramenta
-- @return boolean - true se está no backpack
function ToolUtils.hasToolInBackpack(player: Player, toolName: string): boolean
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		return false
	end

	return backpack:FindFirstChild(toolName) ~= nil
end

--- Verifica se a ferramenta está atualmente sendo segurada (equipada no Character)
-- @param player Player - O jogador
-- @param toolName string - Nome da ferramenta
-- @return boolean - true se está no character (equipada)
function ToolUtils.isToolHeld(player: Player, toolName: string): boolean
	local character = player.Character
	if not character then
		return false
	end

	return character:FindFirstChild(toolName) ~= nil
end

--// ============================================================================
--// SETOR: Retorno do Módulo
--// ============================================================================

return ToolUtils

