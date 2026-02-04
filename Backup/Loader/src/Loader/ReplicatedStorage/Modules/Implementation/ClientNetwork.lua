local SharedTypes = require("../../../ReplicatedStorage/Utilities/SharedTypes")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NETWORK_FOLDER = ReplicatedStorage:WaitForChild("Network") :: Folder
local BALL_EVENTS = NETWORK_FOLDER:FindFirstChild("BallEvents") :: RemoteEvent
local SWITCH_HAND_EVENT = NETWORK_FOLDER:WaitForChild("SwitchHands") :: RemoteEvent
local THROW_EVENT = NETWORK_FOLDER:WaitForChild("ThrowEvent") :: RemoteEvent
local GOALKEEPER_EVENT = NETWORK_FOLDER:WaitForChild("Goalkeeper") :: RemoteEvent
local REFEREE_EVENT = NETWORK_FOLDER:WaitForChild("Referee") :: RemoteEvent
local TACKLING_FUNCTION = NETWORK_FOLDER:WaitForChild("Tackling") :: RemoteFunction
local PLAYERDATA_FUNCTION = NETWORK_FOLDER:WaitForChild("PlayerData") :: RemoteFunction
local LEAGUE_EVENT = NETWORK_FOLDER:WaitForChild("LeagueEvent") :: RemoteEvent

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

function ClientNetwork.LeagueEvent:CallForTechnicalPause()
	LEAGUE_EVENT:FireServer("CALL_FOR_PAUSE")
end


function ClientNetwork.PlayerDataFunction:ChangeKeybind(context: string, action: string, keyName: string)
	return PLAYERDATA_FUNCTION:InvokeServer("CHANGE_KEYBOARD_KEYBIND", {
		context, action, keyName
	})
end

function ClientNetwork.PlayerDataFunction:ChangeGamepad(context: string, action: string, keyName: string)
	return PLAYERDATA_FUNCTION:InvokeServer("CHANGE_GAMEPAD_CONTROLS", {
		context, action, keyName
	})
end

function ClientNetwork.PlayerDataFunction:CustomizeMobile(context: string, action: string, offset: {number}, scalar: number)
	return PLAYERDATA_FUNCTION:InvokeServer("CHANGE_MOBILE_CONTROLS", {
		context, action, offset, scalar
	})
end

function ClientNetwork.PlayerDataFunction:ResetControls()
	return PLAYERDATA_FUNCTION:InvokeServer("RESET_KEYBINDS")
end

function ClientNetwork.BallEvents:SpawnRequest()
	BALL_EVENTS:FireServer("SpawnRequest")
end

function ClientNetwork.BallEvents:ClearRequest()
	BALL_EVENTS:FireServer("ClearRequest")
end

function ClientNetwork.BallEvents:DropRequest()
	BALL_EVENTS:FireServer("DropRequest")
end

function ClientNetwork.SwitchHandsEvent:SwitchRequest()
	SWITCH_HAND_EVENT:FireServer()
end

function ClientNetwork.ThrowEvent:Throw(power: number, directionData: SharedTypes.DirectionData)
	THROW_EVENT:FireServer(power, directionData)
end

function ClientNetwork.GoalkeeperEvent:Save(state: boolean)
	GOALKEEPER_EVENT:FireServer(state)
end

function ClientNetwork.RefereeEvent:AddGoal(isHome: boolean)
	REFEREE_EVENT:FireServer({
		action = "ADD_GOAL",
		isHome = isHome
	})
end

function ClientNetwork.RefereeEvent:RemoveGoal(isHome: boolean)
	REFEREE_EVENT:FireServer({
		action = "REMOVE_GOAL",
		isHome = isHome
	})
end

function ClientNetwork.RefereeEvent:ResetScore()
	REFEREE_EVENT:FireServer({
		action = "RESET_SCORE"
	})
end

function ClientNetwork.RefereeEvent:StartTimer()
	REFEREE_EVENT:FireServer({
		action = "TOGGLE_TIMER",
		state = true
	})
end

function ClientNetwork.RefereeEvent:StopTimer()
	REFEREE_EVENT:FireServer({
		action = "TOGGLE_TIMER",
		state = false
	})
end

function ClientNetwork.RefereeEvent:ToggleBallTimer()
	REFEREE_EVENT:FireServer({
		action = "TOGGLE_BALL_TIMER"
	})
end

function ClientNetwork.RefereeEvent:ChangeTeamName(name: string, isHome: boolean)
	REFEREE_EVENT:FireServer({
		action = "TOGGLE_NAME",
		teamName = name,
		isHome = isHome
	})
end

function ClientNetwork.RefereeEvent:ResetTimer()
	REFEREE_EVENT:FireServer({
		action = "RESET_TIMER"
	})
end

function ClientNetwork.RefereeEvent:RefSpawn(isHome: boolean, position: Vector3)
	REFEREE_EVENT:FireServer({
		action = "REF_SPAWN_BALL",
		isHome = isHome,
		position = position
	})
end

function ClientNetwork.RefereeEvent:RefPenalty(isHome: boolean, isHomeGLT: boolean)
	REFEREE_EVENT:FireServer({
		action = "REF_PENALTY",
		isHome = isHome,
		isHomeGLT = isHomeGLT
	})
end

function ClientNetwork.RefereeEvent:RemoveBalls()
	REFEREE_EVENT:FireServer({
		action = "REMOVE_BALLS"
	})
end

-- New control functions to synchronize referee UI with server commands and statistics
function ClientNetwork.RefereeEvent:BeginLeague()
	REFEREE_EVENT:FireServer({
		action = "BEGIN_LEAGUE"
	})
end

function ClientNetwork.RefereeEvent:ResetMatch()
	REFEREE_EVENT:FireServer({
		action = "RESET_MATCH"
	})
end

function ClientNetwork.RefereeEvent:PauseMatch()
	REFEREE_EVENT:FireServer({
		action = "PAUSE_MATCH"
	})
end

function ClientNetwork.RefereeEvent:ResumeMatch()
	REFEREE_EVENT:FireServer({
		action = "RESUME_MATCH"
	})
end

function ClientNetwork.TacklingFunction:Tackle()
	TACKLING_FUNCTION:InvokeServer()
end


return ClientNetwork

