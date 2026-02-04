--[[
    ================================================================================
    MÓDULO: PingClient
    ================================================================================
    Descrição: Resposta do cliente para medição de latência (ping).
               O servidor envia um invoke e mede o tempo de resposta.
    
    Funcionalidades:
        - Responde ao RemoteFunction de ping do servidor
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: REFERÊNCIAS
--// ============================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NETWORK_FOLDER = ReplicatedStorage:WaitForChild("Network") :: Folder
local PING_FUNCTION = NETWORK_FOLDER:WaitForChild("Ping") :: RemoteFunction

--// ============================================================================
--// SETOR: HANDLER
--// ============================================================================

--- Responde ao ping do servidor
function PING_FUNCTION.OnClientInvoke(): boolean
	return true
end

return {}