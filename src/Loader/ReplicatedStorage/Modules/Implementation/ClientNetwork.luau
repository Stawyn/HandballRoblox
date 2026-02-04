--[[
    ================================================================================
    MÓDULO: ClientNetwork
    ================================================================================
    Descrição: Wrapper de comunicação cliente → servidor para o projeto ABH.
               Abstrai todos os RemoteEvents/RemoteFunctions em uma API limpa.
    
    Namespaces:
        - BallEvents: Spawn, Clear, Drop de bolas
        - SwitchHandsEvent: Troca de mão dominante
        - ThrowEvent: Arremesso de bola
        - GoalkeeperEvent: Ativar/desativar defesa
        - RefereeEvent: Comandos de árbitro
        - TacklingFunction: Tackle/roubo
        - PlayerDataFunction: Keybinds e configurações
        - LeagueEvent: Eventos da partida
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: DEPENDÊNCIAS
--// ============================================================================

local SharedTypes = require("../../../ReplicatedStorage/Utilities/SharedTypes")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// ============================================================================
--// SETOR: REFERÊNCIAS DE REDE
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
--// SETOR: ESTRUTURA DO MÓDULO
--// ============================================================================

local ClientNetwork = {}
ClientNetwork.BallEvents = {}
ClientNetwork.SwitchHandsEvent = {}
ClientNetwork.ThrowEvent = {}
ClientNetwork.GoalkeeperEvent = {}
ClientNetwork.RefereeEvent = {}
ClientNetwork.TacklingFunction = {}
ClientNetwork.PlayerDataFunction = {}
ClientNetwork.LeagueEvent = {}
ClientNetwork.RefereeEventRemote = REFEREE_EVENT

--// ============================================================================
--// SETOR: LEAGUE EVENTS
--// ============================================================================

--- Chama pausa técnica
function ClientNetwork.LeagueEvent:CallForTechnicalPause()
	LEAGUE_EVENT:FireServer("CALL_FOR_PAUSE")
end

--// ============================================================================
--// SETOR: PLAYER DATA (Keybinds)
--// ============================================================================

--- Altera keybind de teclado
function ClientNetwork.PlayerDataFunction:ChangeKeybind(context: string, action: string, keyName: string)
	return PLAYERDATA_FUNCTION:InvokeServer("CHANGE_KEYBOARD_KEYBIND", {
		context, action, keyName
	})
end

--- Altera keybind de gamepad
function ClientNetwork.PlayerDataFunction:ChangeGamepad(context: string, action: string, keyName: string)
	return PLAYERDATA_FUNCTION:InvokeServer("CHANGE_GAMEPAD_CONTROLS", {
		context, action, keyName
	})
end

--- Customiza controles mobile
function ClientNetwork.PlayerDataFunction:CustomizeMobile(context: string, action: string, offset: {number}, scalar: number)
	return PLAYERDATA_FUNCTION:InvokeServer("CHANGE_MOBILE_CONTROLS", {
		context, action, offset, scalar
	})
end

--- Reseta todos os controles para padrão
function ClientNetwork.PlayerDataFunction:ResetControls()
	return PLAYERDATA_FUNCTION:InvokeServer("RESET_KEYBINDS")
end

--// ============================================================================
--// SETOR: BALL EVENTS
--// ============================================================================

--- Solicita spawn de bola
function ClientNetwork.BallEvents:SpawnRequest()
	BALL_EVENTS:FireServer("SpawnRequest")
end

--- Solicita remoção de bolas
function ClientNetwork.BallEvents:ClearRequest()
	BALL_EVENTS:FireServer("ClearRequest")
end

--- Solicita drop da bola
function ClientNetwork.BallEvents:DropRequest()
	BALL_EVENTS:FireServer("DropRequest")
end

--// ============================================================================
--// SETOR: SWITCH HANDS
--// ============================================================================

--- Troca mão dominante
function ClientNetwork.SwitchHandsEvent:SwitchRequest()
	SWITCH_HAND_EVENT:FireServer()
end

--// ============================================================================
--// SETOR: THROW EVENT
--// ============================================================================

--- Arremessa a bola
function ClientNetwork.ThrowEvent:Throw(power: number, directionData: SharedTypes.DirectionData)
	THROW_EVENT:FireServer(power, directionData)
end

--// ============================================================================
--// SETOR: GOALKEEPER
--// ============================================================================

--- Ativa/desativa modo defesa
function ClientNetwork.GoalkeeperEvent:Save(state: boolean)
	GOALKEEPER_EVENT:FireServer(state)
end

--// ============================================================================
--// SETOR: REFEREE EVENTS
--// ============================================================================

--- Adiciona gol
function ClientNetwork.RefereeEvent:AddGoal(isHome: boolean)
	REFEREE_EVENT:FireServer({ action = "ADD_GOAL", isHome = isHome })
end

--- Remove gol
function ClientNetwork.RefereeEvent:RemoveGoal(isHome: boolean)
	REFEREE_EVENT:FireServer({ action = "REMOVE_GOAL", isHome = isHome })
end

--- Reseta placar
function ClientNetwork.RefereeEvent:ResetScore()
	REFEREE_EVENT:FireServer({ action = "RESET_SCORE" })
end

--- Inicia timer
function ClientNetwork.RefereeEvent:StartTimer()
	REFEREE_EVENT:FireServer({ action = "TOGGLE_TIMER", state = true })
end

--- Para timer
function ClientNetwork.RefereeEvent:StopTimer()
	REFEREE_EVENT:FireServer({ action = "TOGGLE_TIMER", state = false })
end

--- Toggle ball timer
function ClientNetwork.RefereeEvent:ToggleBallTimer()
	REFEREE_EVENT:FireServer({ action = "TOGGLE_BALL_TIMER" })
end

--- Altera nome do time
function ClientNetwork.RefereeEvent:ChangeTeamName(name: string, isHome: boolean)
	REFEREE_EVENT:FireServer({ action = "TOGGLE_NAME", teamName = name, isHome = isHome })
end

--- Reseta timer
function ClientNetwork.RefereeEvent:ResetTimer()
	REFEREE_EVENT:FireServer({ action = "RESET_TIMER" })
end

--- Spawn de bola pelo árbitro
function ClientNetwork.RefereeEvent:RefSpawn(isHome: boolean, position: Vector3)
	REFEREE_EVENT:FireServer({ action = "REF_SPAWN_BALL", isHome = isHome, position = position })
end

--- Penalty spawn
function ClientNetwork.RefereeEvent:RefPenalty(isHome: boolean, isHomeGLT: boolean)
	REFEREE_EVENT:FireServer({ action = "REF_PENALTY", isHome = isHome, isHomeGLT = isHomeGLT })
end

--- Remove todas as bolas
function ClientNetwork.RefereeEvent:RemoveBalls()
	REFEREE_EVENT:FireServer({ action = "REMOVE_BALLS" })
end

--- Inicia partida
function ClientNetwork.RefereeEvent:BeginLeague()
	REFEREE_EVENT:FireServer({ action = "BEGIN_LEAGUE" })
end

--- Reseta partida
function ClientNetwork.RefereeEvent:ResetMatch()
	REFEREE_EVENT:FireServer({ action = "RESET_MATCH" })
end

--- Pausa partida
function ClientNetwork.RefereeEvent:PauseMatch()
	REFEREE_EVENT:FireServer({ action = "PAUSE_MATCH" })
end

--- Resume partida
function ClientNetwork.RefereeEvent:ResumeMatch()
	REFEREE_EVENT:FireServer({ action = "RESUME_MATCH" })
end

--// ============================================================================
--// SETOR: TACKLING
--// ============================================================================

--- Executa tackle
function ClientNetwork.TacklingFunction:Tackle()
	TACKLING_FUNCTION:InvokeServer()
end

return ClientNetwork
