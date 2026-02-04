--[[
	================================================================================
	MÃ“DULO: ClientNetwork
	================================================================================
	
	DescriÃ§Ã£o:
		Centraliza todas as chamadas de rede do cliente para o servidor.
		Encapsula RemoteEvents e RemoteFunctions em uma API limpa.
	
	Setores:
		- Ball: Spawn, drop e clear de bolas
		- Throw: Arremesso e fake throw
		- Goalkeeper: AÃ§Ãµes de defesa
		- Referee: Controle de partida (gols, timer, nomes)
		- League: Eventos de liga
		- PlayerData: ConfiguraÃ§Ãµes de controles
		- Tackling: Roubadas de bola
	
	Autor: Sistema ABH
	================================================================================
]]

--// ============================================================================
--// SETOR: DependÃªncias
--// ============================================================================

local SharedTypes = require("../../../ReplicatedStorage/Utilities/SharedTypes")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// ============================================================================
--// SETOR: ReferÃªncias de Rede
--// ============================================================================

local NETWORK_FOLDER = ReplicatedStorage:WaitForChild("Network") :: Folder
local BALL_EVENTS = NETWORK_FOLDER:FindFirstChild("BallEvents") :: RemoteEvent
local SWITCH_HAND_EVENT = NETWORK_FOLDER:WaitForChild("SwitchHands") :: RemoteEvent
local THROW_EVENT = NETWORK_FOLDER:WaitForChild("ThrowEvent") :: RemoteEvent
local GOALKEEPER_EVENT = NETWORK_FOLDER:WaitForChild("Goalkeeper") :: RemoteEvent
local REFEREE_EVENT = NETWORK_FOLDER:WaitForChild("Referee") :: RemoteEvent
local TACKLING_FUNCTION = NETWORK_FOLDER:WaitForChild("Tackling") :: RemoteFunction
local PLAYERDATA_FUNCTION = NETWORK_FOLDER:WaitForChild("PlayerData") :: RemoteFunction
local LEAGUE_EVENT = NETWORK_FOLDER:WaitForChild("LeagueEvent") :: RemoteEvent

--// ============================================================================
--// SETOR: Estrutura do MÃ³dulo
--// ============================================================================

local ClientNetwork = {}

-- Sub-mÃ³dulos organizados por funcionalidade
ClientNetwork.BallEvents = {}
ClientNetwork.SwitchHandsEvent = {}
ClientNetwork.ThrowEvent = {}
ClientNetwork.GoalkeeperEvent = {}
ClientNetwork.RefereeEvent = {}
ClientNetwork.TacklingFunction = {}
ClientNetwork.PlayerDataFunction = {}
ClientNetwork.LeagueEvent = {}

-- ReferÃªncia direta para o RemoteEvent de Ã¡rbitro (usado externamente)
ClientNetwork.RefereeEventRemote = REFEREE_EVENT

--// ============================================================================
--// SETOR: Eventos de Liga
--// ============================================================================

--[[
	Solicita pausa tÃ©cnica ao servidor.
]]
function ClientNetwork.LeagueEvent:CallForTechnicalPause()
	LEAGUE_EVENT:FireServer("CALL_FOR_PAUSE")
end

--// ============================================================================
--// SETOR: ConfiguraÃ§Ãµes do Jogador (PlayerData)
--// ============================================================================

--[[
	Altera a tecla de atalho para uma aÃ§Ã£o especÃ­fica.
	
	@param contexto string - Nome do contexto de input
	@param acao string - Nome da aÃ§Ã£o
	@param nomeTecla string - Nome da nova tecla
	@return any - Resposta do servidor
]]
function ClientNetwork.PlayerDataFunction:ChangeKeybind(contexto: string, acao: string, nomeTecla: string)
	return PLAYERDATA_FUNCTION:InvokeServer("CHANGE_KEYBOARD_KEYBIND", {
		contexto, acao, nomeTecla
	})
end

--[[
	Altera o botÃ£o do gamepad para uma aÃ§Ã£o especÃ­fica.
	
	@param contexto string - Nome do contexto de input
	@param acao string - Nome da aÃ§Ã£o
	@param nomeBotao string - Nome do novo botÃ£o
	@return any - Resposta do servidor
]]
function ClientNetwork.PlayerDataFunction:ChangeGamepad(contexto: string, acao: string, nomeBotao: string)
	return PLAYERDATA_FUNCTION:InvokeServer("CHANGE_GAMEPAD_CONTROLS", {
		contexto, acao, nomeBotao
	})
end

--[[
	Personaliza posiÃ§Ã£o e tamanho de botÃ£o mobile.
	
	@param contexto string - Nome do contexto de input
	@param acao string - Nome da aÃ§Ã£o
	@param offset {number} - Deslocamento [x, y]
	@param escala number - Fator de escala
	@return any - Resposta do servidor
]]
function ClientNetwork.PlayerDataFunction:CustomizeMobile(contexto: string, acao: string, offset: {number}, escala: number)
	return PLAYERDATA_FUNCTION:InvokeServer("CHANGE_MOBILE_CONTROLS", {
		contexto, acao, offset, escala
	})
end

--[[
	Restaura todas as configuraÃ§Ãµes de controle para o padrÃ£o.
	
	@return any - Resposta do servidor
]]
function ClientNetwork.PlayerDataFunction:ResetControls()
	return PLAYERDATA_FUNCTION:InvokeServer("RESET_KEYBINDS")
end

--// ============================================================================
--// SETOR: Eventos de Bola
--// ============================================================================

--[[
	Solicita spawn de uma nova bola.
]]
function ClientNetwork.BallEvents:SpawnRequest()
	BALL_EVENTS:FireServer("SpawnRequest")
end

--[[
	Solicita remoÃ§Ã£o de todas as bolas.
]]
function ClientNetwork.BallEvents:ClearRequest()
	BALL_EVENTS:FireServer("ClearRequest")
end

--[[
	Solicita drop da bola atual.
]]
function ClientNetwork.BallEvents:DropRequest()
	BALL_EVENTS:FireServer("DropRequest")
end

--// ============================================================================
--// SETOR: Troca de MÃ£os
--// ============================================================================

--[[
	Solicita troca de mÃ£o para segurar a bola.
]]
function ClientNetwork.SwitchHandsEvent:SwitchRequest()
	SWITCH_HAND_EVENT:FireServer()
end

--// ============================================================================
--// SETOR: Arremesso
--// ============================================================================

--[[
	Envia dados de arremesso para o servidor.
	
	@param poder number - Poder do arremesso (0-100)
	@param dadosDirecao DirectionData - Dados de direÃ§Ã£o do arremesso
]]
function ClientNetwork.ThrowEvent:Throw(poder: number, dadosDirecao: SharedTypes.DirectionData)
	THROW_EVENT:FireServer(poder, dadosDirecao)
end

--// ============================================================================
--// SETOR: Goleiro
--// ============================================================================

--[[
	Notifica o servidor sobre estado de defesa do goleiro.
	
	@param estado boolean - True se estÃ¡ defendendo, false caso contrÃ¡rio
]]
function ClientNetwork.GoalkeeperEvent:Save(estado: boolean)
	GOALKEEPER_EVENT:FireServer(estado)
end

--// ============================================================================
--// SETOR: Ãrbitro - Controle de Placar
--// ============================================================================

--[[
	Adiciona um gol ao placar.
	
	@param ehHome boolean - True para time da casa, false para visitante
]]
function ClientNetwork.RefereeEvent:AddGoal(ehHome: boolean)
	REFEREE_EVENT:FireServer({
		action = "ADD_GOAL",
		isHome = ehHome
	})
end

--[[
	Remove um gol do placar.
	
	@param ehHome boolean - True para time da casa, false para visitante
]]
function ClientNetwork.RefereeEvent:RemoveGoal(ehHome: boolean)
	REFEREE_EVENT:FireServer({
		action = "REMOVE_GOAL",
		isHome = ehHome
	})
end

--[[
	Reseta o placar para 0x0.
]]
function ClientNetwork.RefereeEvent:ResetScore()
	REFEREE_EVENT:FireServer({
		action = "RESET_SCORE"
	})
end

--// ============================================================================
--// SETOR: Ãrbitro - Controle de Timer
--// ============================================================================

--[[
	Inicia o cronÃ´metro da partida.
]]
function ClientNetwork.RefereeEvent:StartTimer()
	REFEREE_EVENT:FireServer({
		action = "TOGGLE_TIMER",
		state = true
	})
end

--[[
	Para o cronÃ´metro da partida.
]]
function ClientNetwork.RefereeEvent:StopTimer()
	REFEREE_EVENT:FireServer({
		action = "TOGGLE_TIMER",
		state = false
	})
end

--[[
	Alterna o timer da bola.
]]
function ClientNetwork.RefereeEvent:ToggleBallTimer()
	REFEREE_EVENT:FireServer({
		action = "TOGGLE_BALL_TIMER"
	})
end

--[[
	Reseta o cronÃ´metro para zero.
]]
function ClientNetwork.RefereeEvent:ResetTimer()
	REFEREE_EVENT:FireServer({
		action = "RESET_TIMER"
	})
end

--// ============================================================================
--// SETOR: Ãrbitro - Nomes de Times
--// ============================================================================

--[[
	Altera o nome de um time.
	
	@param nome string - Novo nome do time
	@param ehHome boolean - True para time da casa, false para visitante
]]
function ClientNetwork.RefereeEvent:ChangeTeamName(nome: string, ehHome: boolean)
	REFEREE_EVENT:FireServer({
		action = "TOGGLE_NAME",
		teamName = nome,
		isHome = ehHome
	})
end

--// ============================================================================
--// SETOR: Ãrbitro - Spawn de Bola
--// ============================================================================

--[[
	Spawn de bola para cobranÃ§a (free throw).
	
	@param ehHome boolean - Time que vai cobrar
	@param posicao Vector3 - PosiÃ§Ã£o do spawn
]]
function ClientNetwork.RefereeEvent:RefSpawn(ehHome: boolean, posicao: Vector3)
	REFEREE_EVENT:FireServer({
		action = "REF_SPAWN_BALL",
		isHome = ehHome,
		position = posicao
	})
end

--[[
	Spawn de bola para cobranÃ§a de pÃªnalti.
	
	@param ehHome boolean - Time que vai cobrar
	@param ehHomeGLT boolean - Se o gol Ã© do lado Home
]]
function ClientNetwork.RefereeEvent:RefPenalty(ehHome: boolean, ehHomeGLT: boolean)
	REFEREE_EVENT:FireServer({
		action = "REF_PENALTY",
		isHome = ehHome,
		isHomeGLT = ehHomeGLT
	})
end

--[[
	Remove todas as bolas do campo.
]]
function ClientNetwork.RefereeEvent:RemoveBalls()
	REFEREE_EVENT:FireServer({
		action = "REMOVE_BALLS"
	})
end

--// ============================================================================
--// SETOR: Ãrbitro - Controle de Partida
--// ============================================================================

--[[
	Inicia uma nova partida de liga.
]]
function ClientNetwork.RefereeEvent:BeginLeague()
	REFEREE_EVENT:FireServer({
		action = "BEGIN_LEAGUE"
	})
end

--[[
	Reseta a partida atual.
]]
function ClientNetwork.RefereeEvent:ResetMatch()
	REFEREE_EVENT:FireServer({
		action = "RESET_MATCH"
	})
end

--[[
	Pausa a partida.
]]
function ClientNetwork.RefereeEvent:PauseMatch()
	REFEREE_EVENT:FireServer({
		action = "PAUSE_MATCH"
	})
end

--[[
	Retoma a partida pausada.
]]
function ClientNetwork.RefereeEvent:ResumeMatch()
	REFEREE_EVENT:FireServer({
		action = "RESUME_MATCH"
	})
end

--// ============================================================================
--// SETOR: Roubada de Bola
--// ============================================================================

--[[
	Executa uma tentativa de roubada de bola.
	Usa RemoteFunction para garantir resposta do servidor.
]]
function ClientNetwork.TacklingFunction:Tackle()
	TACKLING_FUNCTION:InvokeServer()
end

return ClientNetwork

