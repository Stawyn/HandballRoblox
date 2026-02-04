--[[
	================================================================================
	MÓDULO: Timer (Cronômetro de Partida)
	================================================================================
	
	Descrição:
		Gerencia o cronômetro oficial da partida:
		- Contagem progressiva de tempo
		- Acréscimos de tempo
		- Eventos de fim de tempo
		- Sincronização com interface
	
	Configuração:
		TIMER_DURATION: Tempo em segundos por tempo de jogo (padrào 10 minutos)
	
	Autor: Sistema ABH
	Refatorado: Documentação em PT-BR
	================================================================================
]]

--// ============================================================================
--// SETOR: Dependências
--// ============================================================================

local ServerEvents = require("./ServerEvents")

--// ============================================================================
--// SETOR: Referências de Dados
--// ============================================================================

local DATA_FOLDER = workspace:WaitForChild("Core"):WaitForChild("Data")
local TIMER = DATA_FOLDER:WaitForChild("Timer") :: NumberValue

--// ============================================================================
--// SETOR: Configuração
--// ============================================================================

-- TEMPO DA PARTIDA (Mude aqui para testar rápido, ex: 15 para 15 segundos)
local TIMER_DURATION = 10 * 60  -- 10 minutos por tempo

--// ============================================================================
--// SETOR: Estado Global
--// ============================================================================

local timerRunning = false  -- Se o timer está ativo
local currentTime = 0       -- Tempo atual em segundos
local addedTime = 0         -- Acréscimos em segundos

--// ============================================================================
--// SETOR: Definição do Módulo
--// ============================================================================

local Timer = {}
local thread = nil  -- Thread do loop de contagem

--// ============================================================================
--// SETOR: Funções Públicas
--// ============================================================================

--- Liga ou desliga o cronômetro
-- @param state boolean - True para ligar, false para desligar
function Timer:Toggle(state: boolean)
	if state == timerRunning then
		return
	end

	timerRunning = state 

	-- Cancela thread anterior se existir
	if thread then
		task.cancel(thread)
		thread = nil
	end

	if timerRunning then
		-- Inicia loop de contagem
		thread = task.spawn(function()
			while timerRunning and currentTime < (TIMER_DURATION + addedTime) do
				task.wait(1)
				currentTime += 1
				TIMER.Value = currentTime
			end

			-- Tempo esgotado: notifica fim do tempo
			if currentTime >= (TIMER_DURATION + addedTime) then
				ServerEvents.League:Fire("END_HALF")
			end
		end)
	end
end

--- Define o tempo atual manualmente
-- @param time number - Tempo em segundos
function Timer:SetTime(time: number)
	currentTime = time
	TIMER.Value = currentTime
end

--- Reseta o cronômetro para zero
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
	-- Garante que amount é >= 0
	addedTime += math.max(math.floor(amount), 0) * 60

	-- Se estava em último ataque e ainda tem tempo, cancela
	if DATA_FOLDER.LastAttack.Value == true and currentTime < (TIMER_DURATION + addedTime) then
		DATA_FOLDER.LastAttack.Value = false
	end

	DATA_FOLDER.AddedTime.Value = addedTime
	Timer:Toggle(true)
	ServerEvents.League:Fire("CANCEL_LAST_ATTACK")
end

--// ============================================================================
--// SETOR: Handlers de Eventos
--// ============================================================================

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
		Timer:Toggle(false)
	end
end)

--// ============================================================================
--// SETOR: Retorno do Módulo
--// ============================================================================

return Timer
