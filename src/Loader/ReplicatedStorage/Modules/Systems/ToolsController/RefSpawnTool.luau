--[[
    ================================================================================
    MÓDULO: RefSpawnTool
    ================================================================================
    Descrição: Ferramenta de spawn de bola para set pieces (árbitro).
               Mostra preview visual da posição de spawn.
    
    Funcionalidades:
        - Preview visual da posição do mouse
        - Alternância de time (Home/Away)
        - Spawn de bola na posição indicada
    
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
local REFERENCE_BASEPART = ASSETS_FOLDER:WaitForChild("SpawnReference") :: {
	ForceField: BasePart
} & MeshPart

local localPlayer = Players.LocalPlayer :: Player

--// ============================================================================
--// SETOR: MÓDULO
--// ============================================================================

local RefSpawnTool = {}

--// ============================================================================
--// SETOR: FUNÇÕES AUXILIARES
--// ============================================================================

--- Alterna cor baseado no time (0=Home/Azul, 1=Away/Vermelho)
local function ToggleColor(part: BasePart, n: number)
	part.Color = if n == 0 
		then Color3.fromRGB(0, 0, 255) 
		else Color3.fromRGB(255, 0, 0)
end

--// ============================================================================
--// SETOR: INICIALIZAÇÃO
--// ============================================================================

--- Inicializa a ferramenta
function RefSpawnTool:Initialize(tool: Tool)	
	local toolJanitor = Janitor.new()
	-- n mod 2: 0 = Home, 1 = Away
	local currentTeam = 0
	
	tool.Equipped:Connect(function()
		InputSystem.Contexts["Set Piece Tool"].Enabled = true
		
		local referenceClone = REFERENCE_BASEPART:Clone()
		toolJanitor:Add(referenceClone, "Destroy")
		referenceClone.Parent = workspace
		local position = Vector3.zero
		
		ToggleColor(referenceClone, currentTeam)
		
		-- Update loop
		toolJanitor:Add(RunService.RenderStepped:Connect(function(deltaTime)
			local mouseHit = localPlayer:GetMouse().Hit
			position = (mouseHit.Position * Vector3.new(1, 0, 1)) + Vector3.new(0, referenceClone.Size.Y/2, 0)
			referenceClone.CFrame = CFrame.new(position)
		end), "Disconnect")
		
		-- Spawn
		toolJanitor:Add(InputSystem.Actions["Set Piece Tool"].Spawn.Pressed:Connect(function()
			local isHome = currentTeam == 0
			ClientNetwork.RefereeEvent:RefSpawn(isHome, position)
		end), "Disconnect")
		
		-- Change Team
		toolJanitor:Add(InputSystem.Actions["Set Piece Tool"]["Change Team"].Pressed:Connect(function()
			currentTeam = (currentTeam + 1) % 2
			ToggleColor(referenceClone.ForceField, currentTeam)
		end))
	end)

	tool.Unequipped:Connect(function()
		InputSystem.Contexts["Set Piece Tool"].Enabled = false
		toolJanitor:Cleanup()
	end)

	tool.Destroying:Connect(function()
		toolJanitor:Destroy()
	end)
end

return RefSpawnTool