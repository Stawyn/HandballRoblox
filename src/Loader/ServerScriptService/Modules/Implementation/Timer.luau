--[[
    ================================================================================
    MÓDULO: Timer
    ================================================================================
    Descrição: Sistema de cronometragem da partida ABH.
               Controla o tempo de jogo, acréscimos e eventos de fim de tempo.
    
    Funcionalidades:
        - Toggle: Iniciar/pausar timer
        - Reset: Zerar timer
        - SetTime: Definir tempo específico
        - AddTime: Adicionar acréscimos
    
    Eventos Enviados:
        - END_HALF: Quando timer atinge fim do tempo
        - CANCEL_LAST_ATTACK: Quando acréscimo é adicionado
    
    Configuração:
        - TIMER_DURATION: 10 minutos (600 segundos) por tempo
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: DEPENDÊNCIAS
--// ============================================================================

local ServerEvents = require("./ServerEvents")

--// ============================================================================
--// SETOR: REFERÊNCIAS E CONSTANTES
--// ============================================================================

local DATA_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Data")
local TIMER = DATA_FOLDER:WaitForChild("Timer") :: NumberValue

-- Duração do tempo de jogo (10 minutos = 600 segundos)
-- Altere para valor menor para testes rápidos (ex: 15 segundos)
local TIMER_DURATION = 10 * 60 

--// ============================================================================
--// SETOR: ESTADO
--// ============================================================================

local timerRunning = false
local currentTime = 0
local addedTime = 0
local thread = nil

--// ============================================================================
--// SETOR: MÓDULO
--// ============================================================================

local Timer = {}

--// ============================================================================
--// SETOR: FUNÇÕES PÚBLICAS
--// ============================================================================

--- Inicia ou pausa o timer
-- @param state boolean - true para iniciar, false para pausar
function Timer:Toggle(state: boolean)
	if state == timerRunning then
		return
	end

	timerRunning = state 
	
	-- Cancela thread anterior
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

			-- Fim do tempo
			if currentTime >= (TIMER_DURATION + addedTime) then
				ServerEvents.League:Fire("END_HALF")
			end
		end)
	end
end

--- Define o tempo atual
-- @param time number - Tempo em segundos
function Timer:SetTime(time: number)
	currentTime = time
	TIMER.Value = currentTime
end

--- Reseta o timer para zero
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

--- Adiciona tempo de acréscimo
-- @param amount number - Minutos a adicionar
function Timer:AddTime(amount: number)
	addedTime += math.max(math.floor(amount), 0) * 60
	
	-- Cancela último ataque se timer ainda não acabou
	if DATA_FOLDER.LastAttack.Value == true and currentTime < (TIMER_DURATION + addedTime) then
		DATA_FOLDER.LastAttack.Value = false
	end
	
	DATA_FOLDER.AddedTime.Value = addedTime
	Timer:Toggle(true)
	ServerEvents.League:Fire("CANCEL_LAST_ATTACK")
end

--// ============================================================================
--// SETOR: LISTENERS DE EVENTOS
--// ============================================================================

ServerEvents.League:Connect(function(action, ...)
	if action == "START" then
		Timer:Reset()
		Timer:Toggle(true)
	elseif action == "RESET" then
		Timer:Reset()
	elseif action == "RESET_TIME" then
		Timer:Reset()
	elseif action == "SET_TIME" then
		Timer:SetTime(...)
	elseif action == "PAUSE" then
		Timer:Toggle(false)
	end
end)

return Timer
