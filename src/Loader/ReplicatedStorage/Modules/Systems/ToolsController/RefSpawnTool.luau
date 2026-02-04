--[[
	================================================================================
	MÃ“DULO: RefSpawnTool
	================================================================================
	
	DescriÃ§Ã£o:
		Ferramenta de Ãrbitro para marcaÃ§Ã£o de faltas/reinÃ­cios (Set Piece).
		Permite posicionar a bola e definir qual time tem a posse.
	
	Funcionalidades:
		- VisualizaÃ§Ã£o fantasama (ghost) de onde a bola serÃ¡ criada.
		- AlternÃ¢ncia de time (Casa/Visitante) para posse de bola.
		- RequisiÃ§Ã£o de spawn ao servidor.
	
	DependÃªncias:
		- ClientNetwork (ComunicaÃ§Ã£o)
		- Janitor (Limpeza de memÃ³ria)
		- InputSystem (Entrada)
	
	Autor: Sistema ABH
	================================================================================
]]

--// ============================================================================
--// SETOR: ServiÃ§os
--// ============================================================================

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

--// ============================================================================
--// SETOR: DependÃªncias
--// ============================================================================

local ClientNetwork = require("../../Implementation/ClientNetwork")
local Janitor = require("../../../Utilities/Janitor")
local InputSystem = require("../../Implementation/InputSystem")

local ASSETS_FOLDER = ReplicatedStorage:WaitForChild("Assets")
local REFERENCE_BASEPART = ASSETS_FOLDER:WaitForChild("SpawnReference") :: {
	ForceField: BasePart
} & MeshPart

local localPlayer = Players.LocalPlayer :: Player
local SpawnTool = {}

--// ============================================================================
--// SETOR: FunÃ§Ãµes Auxiliares
--// ============================================================================

--[[
	Alterna a cor da parte baseada no Ã­ndice do time.
	
	@param part BasePart - A parte a ser colorida
	@param n number - Ãndice do time (0 = Casa/Azul, 1 = Visitante/Vermelho)
]]
function ToggleColor(part: BasePart, n: number)
	if n == 0 then
		part.Color = Color3.fromRGB(0, 0, 255) -- Azul (Home)
	else
		part.Color = Color3.fromRGB(255, 0, 0) -- Vermelho (Away)
	end
end

--// ============================================================================
--// SETOR: InicializaÃ§Ã£o
--// ============================================================================

function SpawnTool:Initialize(tool: Tool)	
	local toolJanitor = Janitor.new()

	-- Controle do time atual:
	-- n (inteiro) % 2 -> 0 = Home Team, 1 = Away Team
	local currentTeam = 0

	-- Evento de Equipar
	tool.Equipped:Connect(function()
		InputSystem.Contexts["Set Piece Tool"].Enabled = true

		-- Cria visualizaÃ§Ã£o fantasma (Ghost)
		local referenceClone = REFERENCE_BASEPART:Clone()
		toolJanitor:Add(referenceClone, "Destroy")
		referenceClone.Parent = workspace

		local position = Vector3.zero

		-- Aplica cor inicial
		ToggleColor(referenceClone, currentTeam)

		-- Atualiza posiÃ§Ã£o do ghost a cada frame (seguir mouse)
		toolJanitor:Add(RunService.RenderStepped:Connect(function(deltaTime)
			local mouseHit = localPlayer:GetMouse().Hit
			-- MantÃ©m Y fixo baseado no tamanho do objeto
			position = (mouseHit.Position * Vector3.new(1, 0, 1)) + Vector3.new(0, referenceClone.Size.Y/2, 0)

			referenceClone.CFrame = CFrame.new(position)
		end), "Disconnect")

		-- AÃ§Ã£o: Spawnar Bola
		toolJanitor:Add(InputSystem.Actions["Set Piece Tool"].Spawn.Pressed:Connect(function()
			local isHome = currentTeam == 0
			ClientNetwork.RefereeEvent:RefSpawn(isHome, position)
		end), "Disconnect")

		-- AÃ§Ã£o: Trocar Time
		toolJanitor:Add(InputSystem.Actions["Set Piece Tool"]["Change Team"].Pressed:Connect(function()
			currentTeam = (currentTeam + 1) % 2
			ToggleColor(referenceClone.ForceField, currentTeam)
		end))
	end)

	-- Evento de Desequipar
	tool.Unequipped:Connect(function()
		InputSystem.Contexts["Set Piece Tool"].Enabled = false
		toolJanitor:Cleanup()
	end)

	-- Evento de Destruir
	tool.Destroying:Connect(function()
		toolJanitor:Destroy()
	end)
end

return SpawnTool

