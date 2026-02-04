--[[
    ================================================================================
    MÓDULO: PenaltySpawnTool
    ================================================================================
    Descrição: Ferramenta de spawn de pênalti para árbitros.
               Detecta automaticamente o gol mais próximo.
    
    Funcionalidades:
        - Detecção automática do GLT mais próximo
        - Preview visual da posição de pênalti
        - Alternância de time cobrador
        - Spawn de bola de pênalti
    
    Cores:
        - Azul: Home Team
        - Vermelho: Away Team
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: SERVIÇOS E DEPENDÊNCIAS
--// ============================================================================

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ClientNetwork = require("../../Implementation/ClientNetwork")
local Janitor = require("../../../Utilities/Janitor")
local InputSystem = require("../../Implementation/InputSystem")

--// ============================================================================
--// SETOR: REFERÊNCIAS
--// ============================================================================

local ASSETS_FOLDER = ReplicatedStorage:WaitForChild("Assets")
local HOME_PENALTY = ASSETS_FOLDER.Penalty.Home :: BasePart
local AWAY_PENALTY = ASSETS_FOLDER.Penalty.Away :: BasePart

local localPlayer = Players.LocalPlayer :: Player

--// ============================================================================
--// SETOR: ESTADO
--// ============================================================================

local penaltyPart: BasePart? = nil

--// ============================================================================
--// SETOR: MÓDULO
--// ============================================================================

local PenaltySpawnTool = {}

--// ============================================================================
--// SETOR: FUNÇÕES AUXILIARES
--// ============================================================================

--- Alterna cor baseado no time (0=Home/Azul, 1=Away/Vermelho)
local function ToggleColor(part: BasePart?, n: number)
	if not part then return end
	part.Color = if n == 0 
		then Color3.fromRGB(0, 0, 255) 
		else Color3.fromRGB(255, 0, 0)
end

--- Encontra o GLT mais próximo da posição
local function getClosestGLT(position: Vector3)
	local closest = nil
	local distance = math.huge
	
	for _, v in workspace.Core.GLT:GetChildren() do
		local distanceToGLT = (v.Position - position).Magnitude
		if distanceToGLT < distance then
			distance = distanceToGLT
			closest = v
		end
	end
	
	return closest
end

--- Cria/atualiza a parte de preview do pênalti
local function createPart(glt)
	-- Limpa se mudou de gol
	if penaltyPart then
		if penaltyPart.Name ~= glt.Name then
			penaltyPart:Destroy()
			penaltyPart = nil
		end
	end
	
	-- Cria novo preview
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
--// SETOR: INICIALIZAÇÃO
--// ============================================================================

--- Inicializa a ferramenta
function PenaltySpawnTool:Initialize(tool: Tool)	
	local toolJanitor = Janitor.new()
	-- n mod 2: 0 = Home, 1 = Away
	local currentTeam = 0
	local closest = nil
	
	toolJanitor:LinkToInstance(tool)
	
	tool.Equipped:Connect(function()
		InputSystem.Contexts["Penalty Tool"].Enabled = true

		-- Update loop
		toolJanitor:Add(RunService.RenderStepped:Connect(function()
			closest = getClosestGLT(localPlayer:GetMouse().Hit.Position)
			createPart(closest)
			ToggleColor(penaltyPart, currentTeam)
		end))
		
		-- Spawn
		toolJanitor:Add(InputSystem.Actions["Penalty Tool"].Spawn.Pressed:Connect(function()
			local isHome = currentTeam == 0
			local isHomeGLT = closest.Name == "Home"
			ClientNetwork.RefereeEvent:RefPenalty(isHome, isHomeGLT)
		end), "Disconnect")
		
		-- Change Team
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

return PenaltySpawnTool