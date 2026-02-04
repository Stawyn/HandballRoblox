--!nocheck
--[[
	================================================================================
	SCRIPT: Init (Servidor)
	================================================================================
	
	Descrição:
		Script de inicialização do lado do Servidor.
		Responsável por carregar os módulos de sistema do servidor.
	
	Localização:
		ServerScriptService/Init
	
	Funcionalidades:
		- Carrega módulos em ServerScriptService/Modules/Systems.
	
	Autor: Sistema ABH
	================================================================================
]]

--// ============================================================================
--// SETOR: Serviços
--// ============================================================================

local ServerScriptService = game:GetService("ServerScriptService")

--// ============================================================================
--// SETOR: Referências
--// ============================================================================

local modulesFolder = ServerScriptService:WaitForChild("Modules", 15)
if not modulesFolder then
	warn("[Init] Pasta Modules não encontrada em ServerScriptService após 15 segundos")
	return
end
local systemsFolder = modulesFolder:WaitForChild("Systems", 10)
if not systemsFolder then
	warn("[Init] Pasta Systems não encontrada em Modules após 10 segundos")
	return
end

--// ============================================================================
--// SETOR: Carregamento de Módulos
--// ============================================================================

-- Itera e carrega todos os ModuleScripts na pasta de sistemas do servidor
for _, module in systemsFolder:GetChildren() do
	if module:IsA("ModuleScript") then
		-- O require executa o código do módulo imediatamente
		require(module)
	end
end
