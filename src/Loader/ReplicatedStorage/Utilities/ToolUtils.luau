--[[
	================================================================================
	MÃ“DULO: ToolUtils (UtilitÃ¡rios de Ferramentas)
	================================================================================
	
	DescriÃ§Ã£o:
		FunÃ§Ãµes centralizadas para gerenciamento de ferramentas (Tools).
		Evita duplicaÃ§Ã£o de cÃ³digo entre diferentes ferramentas do projeto.
	
	FunÃ§Ãµes:
		- isToolEquipped: Verifica se uma ferramenta estÃ¡ equipada
		- getEquippedTool: Retorna a ferramenta equipada ou nil
		- hasToolInBackpack: Verifica se tem ferramenta no Backpack
	
	Autor: Sistema ABH
	================================================================================
]]

--// ============================================================================
--// SETOR: ServiÃ§os do Roblox
--// ============================================================================

local Players = game:GetService("Players")

--// ============================================================================
--// SETOR: DefiniÃ§Ã£o do MÃ³dulo
--// ============================================================================

local ToolUtils = {}

--// ============================================================================
--// SETOR: FunÃ§Ãµes de VerificaÃ§Ã£o
--// ============================================================================

--- Verifica se uma ferramenta especÃ­fica estÃ¡ equipada pelo jogador
-- @param player Player - O jogador a verificar
-- @param toolName string - Nome da ferramenta
-- @return boolean - true se a ferramenta estÃ¡ equipada
function ToolUtils.isToolEquipped(player: Player, toolName: string): boolean
	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character

	if not character then
		return false
	end

	-- Verifica no Backpack (nÃ£o equipada = estÃ¡ lÃ¡)
	if backpack and backpack:FindFirstChild(toolName) then
		return true
	end

	-- Verifica no Character (equipada = estÃ¡ no Character)
	if character:FindFirstChild(toolName) then
		return true
	end

	return false
end

--- Verifica se o jogador local tem uma ferramenta especÃ­fica
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

--- Retorna a instÃ¢ncia da ferramenta se estiver equipada no Character
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

--- Verifica se a ferramenta estÃ¡ no Backpack (nÃ£o equipada)
-- @param player Player - O jogador
-- @param toolName string - Nome da ferramenta
-- @return boolean - true se estÃ¡ no backpack
function ToolUtils.hasToolInBackpack(player: Player, toolName: string): boolean
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		return false
	end

	return backpack:FindFirstChild(toolName) ~= nil
end

--- Verifica se a ferramenta estÃ¡ atualmente sendo segurada (equipada no Character)
-- @param player Player - O jogador
-- @param toolName string - Nome da ferramenta
-- @return boolean - true se estÃ¡ no character (equipada)
function ToolUtils.isToolHeld(player: Player, toolName: string): boolean
	local character = player.Character
	if not character then
		return false
	end

	return character:FindFirstChild(toolName) ~= nil
end

--// ============================================================================
--// SETOR: Retorno do MÃ³dulo
--// ============================================================================

return ToolUtils

