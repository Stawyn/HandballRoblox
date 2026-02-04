local TimerModule = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GAMECONFIG = ReplicatedStorage:WaitForChild("Config")

local MINIMUM_PLAYERS = GAMECONFIG.MINIMUM_PLAYERS.Value
local matchStats: Folder = workspace:WaitForChild("Core"):WaitForChild("Stats")
local gameEvents = game:GetService("ReplicatedStorage"):WaitForChild("Bindable"):WaitForChild("GameEvents")

local minutes: number, seconds: number = 0, 0
local running: boolean = false
local lastAttack = false

function TimerModule:Resume()
	if running then return end
	if lastAttack then return end
	running = true
	task.spawn(function()
		while running do
			task.wait(1)
			if not running then break end
			if seconds < 59 then seconds += 1 else seconds = 0; minutes += 1; end
			
			local stringSeconds: string = seconds >= 10 and tostring(seconds) or "0"..tostring(seconds)
			local timerString: string = tostring(minutes)..":"..stringSeconds
			matchStats.Time.Value = timerString
			
			if minutes >= 8 then
				running = false
				lastAttack = true
				gameEvents:Fire("Last Attack")
				break
			end
		end
	end)
end

function TimerModule:Pause()
	if lastAttack then return end
	running = false
	local stringSeconds: string = seconds >= 10 and tostring(seconds) or "0"..tostring(seconds)
	matchStats.Time.Value = "P "..tostring(minutes)..":"..stringSeconds
end

function TimerModule:Reset()
	lastAttack = false
	running = false
	minutes, seconds = 0, 0
	matchStats.Time.Value = "P 0:00"
end

function TimerModule:SetLAText(side: "Home" | "Away")
	matchStats.Time.Value = "LA - "..side
end

function TimerModule:GetLA(): boolean
	return lastAttack
end

Players.PlayerRemoving:Connect(function()
	if #Players:GetPlayers() < MINIMUM_PLAYERS then
		running = false
		lastAttack = true
		gameEvents:Fire("Last Attack")
	end
end)

return TimerModule
