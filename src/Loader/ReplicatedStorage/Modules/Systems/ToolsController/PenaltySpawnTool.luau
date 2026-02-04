--[[
	================================================================================
	MÓDULO: PenaltySpawnTool
	================================================================================
	
	Descrição:
		Ferramenta para marcação de pênaltis.
		Detecta automaticamente a linha de gol (GLT) mais próxima para posicionar a marca.
	
	Funcionalidades:
		- Detecção automática de gol próxuimo.
		- Posicionamento de marca visual de pênalti.
		- Alternà¢ncia de time cobrador.
	
	Autor: Sistema ABH
	================================================================================
]]

--// ============================================================================
--// SETOR: Serviços
--// ============================================================================

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

--// ============================================================================
--// SETOR: Dependências e Assets
--// ============================================================================

local ClientNetwork = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Implementation"):WaitForChild("ClientNetwork"))
local Janitor = require(game:GetService("ReplicatedStorage"):WaitForChild("Utilities"):WaitForChild("Janitor"))
local InputSystem = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Implementation"):WaitForChild("InputSystem"))

local ASSETS_FOLDER = ReplicatedStorage:WaitForChild("Assets")
local HOME_PENALTY = ASSETS_FOLDER.Penalty.Home :: BasePart
local AWAY_PENALTY = ASSETS_FOLDER.Penalty.Away :: BasePart

local SpawnTool = {}

--// ============================================================================
--// SETOR: Estado
--// ============================================================================

local localPlayer = Players.LocalPlayer :: Player
local penaltyPart: BasePart?

--// ============================================================================
--// SETOR: Funções Auxiliares
--// ============================================================================

--[[
	Alterna a cor da parte baseada no time.
]]
function ToggleColor(part: BasePart?, n: number)
	if not part then return end

	if n == 0 then
		part.Color = Color3.fromRGB(0, 0, 255) -- Azul
	else
		part.Color = Color3.fromRGB(255, 0, 0) -- Vermelho
	end
end

--[[
	Encontra o objeto GLT (Goal Line Technology - Gol) mais próximo de uma posição.
	
	@param position Vector3 - Posição de referência (mouse)
	@return BasePart - O objeto GLT mais próximo
]]
function getClosestGLT(position: Vector3)
	local closest
	local distance = math.huge

	-- Itera sobre os gols na pasta Core/GLT
	if workspace:FindFirstChild("Core") and workspace.Core:FindFirstChild("GLT") then
		for _, v in workspace.Core.GLT:GetChildren() do
			local distanceToGLT = (v.Position - position).Magnitude
			if distanceToGLT < distance then
				distance = distanceToGLT
				closest = v
			end
		end
	end

	return closest
end

--[[
	Cria ou atualiza a parte visual da marca do pênalti baseada no gol alvo.
]]
function createPart(glt)
	if not glt then return end

	-- Se mudou o gol alvo, destroi a marca anterior
	if penaltyPart then
		if penaltyPart.Name ~= glt.Name then
			penaltyPart:Destroy()
			penaltyPart = nil
		end
	end

	-- Cria nova marca se necessário
	if not penaltyPart then
		if glt.Name == "Home" then
			penaltyPart = HOME_PENALTY:Clone()
			penaltyPart.Parent = workspace
		elseif glt.Name == "Away" then
			penaltyPart = AWAY_PENALTY:Clone()
			penaltyPart.Parent = workspace
		end
	end
end

--// ============================================================================
--// SETOR: Inicialização
--// ============================================================================

function SpawnTool:Initialize(tool: Tool)	
	local toolJanitor = Janitor.new()

	-- 0 = Home Team, 1 = Away Team
	local currentTeam = 0
	local closest

	-- Janitor limpa a instà¢ncia da tool se o janitor for limpo
	toolJanitor:LinkToInstance(tool)

	tool.Equipped:Connect(function()
		InputSystem.Contexts["Penalty Tool"].Enabled = true

		-- Loop de visualização
		toolJanitor:Add(RunService.RenderStepped:Connect(function()
			closest = getClosestGLT(localPlayer:GetMouse().Hit.Position)
			if closest then
				createPart(closest)
				ToggleColor(penaltyPart, currentTeam)
			end
		end))

		-- Ação: Marcar Pênalti
		toolJanitor:Add(InputSystem.Actions["Penalty Tool"].Spawn.Pressed:Connect(function()
			if not closest then return end

			local isHome = currentTeam == 0
			local isHomeGLT = closest.Name == "Home"
			ClientNetwork.RefereeEvent:RefPenalty(isHome, isHomeGLT)
		end), "Disconnect")

		-- Ação: Trocar Time
		toolJanitor:Add(InputSystem.Actions["Penalty Tool"]["Change Team"].Pressed:Connect(function()
			currentTeam = (currentTeam + 1) % 2
			ToggleColor(penaltyPart, currentTeam)
		end), "Disconnect")
	end)

	tool.Unequipped:Connect(function()
		InputSystem.Contexts["Penalty Tool"].Enabled = false

		if penaltyPart then
			penaltyPart:Destroy()
			penaltyPart = nil
		end

		closest = nil
		toolJanitor:Cleanup()
	end)

	tool.Destroying:Connect(function()
		if penaltyPart then
			penaltyPart:Destroy()
			penaltyPart = nil
		end

		closest = nil
	end)
end

return SpawnTool

