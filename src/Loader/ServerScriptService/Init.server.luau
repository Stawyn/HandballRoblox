--[[
    ================================================================================
    SCRIPT: Init.server
    ================================================================================
    Descricao: Script de inicializacao do servidor - carrega todos os modulos
               de sistema automaticamente.
    
    Funcionalidades:
        - Carrega todos os ModuleScripts de ServerScriptService/Modules/Systems
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: SERVICOS
--// ============================================================================

--!nocheck
local ServerScriptService = game:GetService("ServerScriptService")

--// ============================================================================
--// SETOR: CARREGAMENTO DE MODULOS
--// ============================================================================

local modules = ServerScriptService:WaitForChild("Modules"):WaitForChild("Systems")

for _, v in modules:GetChildren() do
	if v:IsA("ModuleScript") then
		require(v)
	end
end