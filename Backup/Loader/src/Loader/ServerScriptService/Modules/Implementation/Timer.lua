local ServerEvents = require("./ServerEvents")

local DATA_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Data")
local TIMER = DATA_FOLDER:WaitForChild("Timer") :: NumberValue

-- TEMPO DA PARTIDA (Mude aqui para testar rÃƒÂ¡pido, ex: 15 para 15 segundos)
local TIMER_DURATION = 10 * 60 

local timerRunning = false
local currentTime = 0
local addedTime = 0

local Timer = {}
local thread

function Timer:Toggle(state: boolean)
	if state == timerRunning then
		return
	end

	timerRunning = state 
	if thread then
		task.cancel(thread)
		thread = nil
	end

	if timerRunning then
		thread = task.spawn(function()
			while timerRunning and currentTime < (TIMER_DURATION + addedTime) do
				task.wait(1)
				currentTime += 1
				TIMER.Value = currentTime
			end

			if currentTime >= (TIMER_DURATION + addedTime) then
				ServerEvents.League:Fire("END_HALF")
			end
		end)
	end
end

function Timer:SetTime(time: number)
	currentTime = time
	TIMER.Value = currentTime
end

function Timer:Reset()
	timerRunning = false
	currentTime = 0
	addedTime = 0
	TIMER.Value = currentTime
	DATA_FOLDER.AddedTime.Value = addedTime

	if thread then
		task.cancel(thread)
		thread = nil
	end
end

function Timer:AddTime(amount: number)
	addedTime += math.max(math.floor(amount), 0) * 60 -- we must make sure that the ammount is >= 0
	if DATA_FOLDER.LastAttack.Value == true and currentTime < (TIMER_DURATION + addedTime) then
		DATA_FOLDER.LastAttack.Value = false
	end
	DATA_FOLDER.AddedTime.Value = addedTime
	Timer:Toggle(true)
	ServerEvents.League:Fire("CANCEL_LAST_ATTACK")
end

ServerEvents.League:Connect(function(action, ...)
	if action == "START" then
		Timer:Reset()
		Timer:Toggle(true)
	elseif action == "RESET" then
		Timer:Reset()
	elseif action == "RESET_TIME" then
		-- Reset only the timer value (keep scores, halves, etc)
		Timer:Reset()
	elseif action == "SET_TIME" then
		Timer:SetTime(...)
	elseif action == "PAUSE" then
		-- Pause the timer
		Timer:Toggle(false)
	end
end)

return Timer



