--[[
	================================================================================
	MÃ“DULO: InputSystem (Sistema de Entrada)
	================================================================================
	
	DescriÃ§Ã£o:
		Gerencia todos os inputs do jogador (teclado, gamepad, mobile).
		Fornece acesso centralizado aos contextos e aÃ§Ãµes de input.
		Detecta automaticamente o tipo de dispositivo e ajusta a UI.
	
	Setores:
		- Contextos: Golkeeper, Physical, Throw Tool, Hands, Referee, etc.
		- AÃ§Ãµes: AÃ§Ãµes especÃ­ficas dentro de cada contexto
		- DetecÃ§Ã£o de dispositivo: Mobile, Gamepad, Teclado
		- Redimensionamento de UI: Adapta botÃµes ao tamanho da tela
	
	Autor: Sistema ABH
	Refatorado: DocumentaÃ§Ã£o em PT-BR
	================================================================================
]]

--// ============================================================================
--// SETOR: ServiÃ§os do Roblox
--// ============================================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

--// ============================================================================
--// SETOR: ReferÃªncias do Jogador
--// ============================================================================

local localPlayer = Players.LocalPlayer :: Player
local inputFolder = localPlayer:WaitForChild("InputSystem", math.huge) :: Folder
local playerGui = localPlayer.PlayerGui

-- ReferÃªncias de UI
local mobileUI = playerGui:WaitForChild("Mobile")
local indicatorMain = playerGui:WaitForChild("Indicator"):WaitForChild("Main") :: Frame

--// ============================================================================
--// SETOR: DefiniÃ§Ã£o do MÃ³dulo
--// ============================================================================

local InputSystem = {
	--// ------------------------------------------------------------------
	--// Contextos de Input
	--// Cada contexto agrupa aÃ§Ãµes relacionadas e pode ser habilitado/desabilitado
	--// ------------------------------------------------------------------
	Contexts = {
		Golkeeper = inputFolder:WaitForChild("Goalkeeper") :: InputContext,
		Physical = inputFolder:WaitForChild("Physical") :: InputContext,
		["Throw Tool"] = inputFolder:WaitForChild("Throw Tool") :: InputContext,
		["Hands"] = inputFolder:WaitForChild("Hands") :: InputContext,
		["Referee General"] = inputFolder:WaitForChild("Referee General") :: InputContext,
		["Spawn Tool"] = inputFolder:WaitForChild("Spawn Tool") :: InputContext,
		["Set Piece Tool"] = inputFolder:WaitForChild("Set Piece Tool") :: InputContext,
		["Penalty Tool"] = inputFolder:WaitForChild("Penalty Tool") :: InputContext,
		["General"] = inputFolder:WaitForChild("General") :: InputContext
	},

	--// ------------------------------------------------------------------
	--// AÃ§Ãµes de Input
	--// Cada aÃ§Ã£o representa uma aÃ§Ã£o especÃ­fica que o jogador pode executar
	--// ------------------------------------------------------------------
	Actions = {
		-- AÃ§Ãµes do Goleiro
		Goalkeeper = {
			["Left Predict"] = inputFolder:WaitForChild("Goalkeeper"):WaitForChild("Left Predict") :: InputAction,
			["Right Predict"] = inputFolder:WaitForChild("Goalkeeper"):WaitForChild("Right Predict") :: InputAction
		},

		-- AÃ§Ãµes FÃ­sicas (corrida, etc.)
		Physical = {
			Sprint = inputFolder:WaitForChild("Physical"):WaitForChild("Sprint") :: InputAction
		},

		-- AÃ§Ãµes da Ferramenta de Arremesso
		["Throw Tool"] = {
			["Fake Throw"] = inputFolder:WaitForChild("Throw Tool"):WaitForChild("Fake Throw") :: InputAction,
			Throw = inputFolder:WaitForChild("Throw Tool"):WaitForChild("Throw") :: InputAction,
			Tackle = inputFolder:WaitForChild("Throw Tool"):WaitForChild("Tackle") :: InputAction
		},

		-- AÃ§Ãµes de Troca de MÃ£os
		Hands = {
			["Switch Hand"] = inputFolder:WaitForChild("Hands"):WaitForChild("Switch Hand") :: InputAction
		},

		-- AÃ§Ãµes Gerais do Ãrbitro
		["Referee General"] = {
			["Remove balls"] = inputFolder:WaitForChild("Referee General"):WaitForChild("Remove balls") :: InputAction
		},

		-- AÃ§Ãµes da Ferramenta de Spawn
		["Spawn Tool"] = {
			Spawn = inputFolder:WaitForChild("Spawn Tool"):WaitForChild("Spawn") :: InputAction,
			["Remove balls"] = inputFolder:WaitForChild("Spawn Tool"):WaitForChild("Remove balls") :: InputAction
		},

		-- AÃ§Ãµes da Ferramenta de CobranÃ§a
		["Set Piece Tool"] = {
			Spawn = inputFolder:WaitForChild("Set Piece Tool"):WaitForChild("Spawn") :: InputAction,
			["Change Team"] = inputFolder:WaitForChild("Set Piece Tool"):WaitForChild("Change Team") :: InputAction
		},

		-- AÃ§Ãµes da Ferramenta de PÃªnalti
		["Penalty Tool"] = {
			Spawn = inputFolder:WaitForChild("Penalty Tool"):WaitForChild("Spawn") :: InputAction,
			["Change Team"] = inputFolder:WaitForChild("Penalty Tool"):WaitForChild("Change Team") :: InputAction
		},

		-- AÃ§Ãµes Gerais
		["General"] = {
			Shiftlock = inputFolder:WaitForChild("General"):WaitForChild("Shiftlock") :: InputAction
		}
	}
}

--// ============================================================================
--// SETOR: FunÃ§Ãµes Auxiliares
--// ============================================================================

--- Retorna o tamanho presumido dos botÃµes baseado no tamanho da tela
-- @return number - Tamanho em pixels
function InputSystem:GetPresumedButtonSize()
	local minAxis = math.min(workspace.CurrentCamera.ViewportSize.X, workspace.CurrentCamera.ViewportSize.Y)
	local presumedSize = 40

	-- Escala progressiva baseada na resoluÃ§Ã£o
	if minAxis >= 370 then
		presumedSize = 44
	end
	if minAxis >= 600 then
		presumedSize = 72
	end
	if minAxis >= 765 then
		presumedSize = 88
	end

	return presumedSize
end

--// ============================================================================
--// SETOR: DetecÃ§Ã£o de Dispositivo
--// ============================================================================

--- Atualiza atributos e UI baseado no tipo de input preferido
local function PreferredInputChanged()
	local preferredInput = UserInputService.PreferredInput

	if preferredInput == Enum.PreferredInput.Touch then
		-- MOBILE: Habilita controles touch
		localPlayer:SetAttribute("Mobile", true)
		localPlayer:SetAttribute("Gamepad", false)
		InputSystem.Actions.Physical.Sprint.Enabled = false -- Mobile nÃ£o usa sprint

	elseif preferredInput == Enum.PreferredInput.Gamepad then
		-- CONSOLE: Habilita controles de gamepad
		localPlayer:SetAttribute("Mobile", false)
		localPlayer:SetAttribute("Gamepad", true)

	else 
		-- KEYBOARD: Modo padrÃ£o (teclado + mouse)
		localPlayer:SetAttribute("Mobile", false)
		localPlayer:SetAttribute("Gamepad", false)
		InputSystem.Actions.Physical.Sprint.Enabled = true
	end

	-- Atualiza visibilidade das UIs
	mobileUI.Enabled = localPlayer:GetAttribute("Mobile")

	local keybindShowerUI = playerGui:WaitForChild("Classic")
	keybindShowerUI.Enabled = not localPlayer:GetAttribute("Mobile")
end

-- Inicializa detecÃ§Ã£o de dispositivo
PreferredInputChanged()
UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(PreferredInputChanged)

--// ============================================================================
--// SETOR: Gerenciamento de Visibilidade de Contextos
--// ============================================================================

--- Atualiza visibilidade dos botÃµes mobile quando contexto muda
local function onContextEnableChange(v: InputContext)
	for u, w in InputSystem.Actions[v.Name] do
		local inputAction = w :: InputAction
		local mobileBinding = w:FindFirstChild("Mobile") :: InputBinding
		if mobileBinding then
			mobileBinding.UIButton.Parent.Visible = v.Enabled
		end
	end
end

-- Conecta handlers de visibilidade para todos os contextos
for i, v in InputSystem.Contexts do
	local context = v :: InputContext
	coroutine.wrap(onContextEnableChange)(context)
	context:GetPropertyChangedSignal("Enabled"):Connect(function()
		coroutine.wrap(onContextEnableChange)(context)
	end)
end

--// ============================================================================
--// SETOR: Redimensionamento de BotÃµes Mobile
--// ============================================================================

--- Redimensiona botÃµes de um contexto especÃ­fico
local function resizeButtons(v: InputContext)
	local presumedSize = InputSystem:GetPresumedButtonSize()

	for u, w in InputSystem.Actions[v.Name] do
		local inputAction = w :: InputAction
		local mobileBinding = w:FindFirstChild("Mobile") :: InputBinding
		if mobileBinding and mobileBinding.UIButton then
			local presumedUI = mobileBinding.UIButton.Parent
			local scalar = presumedUI:GetAttribute("Scalar") or 1
			local offsetPos = UDim2.fromOffset(
				presumedUI:GetAttribute("PosOffsetX") or 0, 
				presumedUI:GetAttribute("PosOffsetY") or 0
			)

			presumedUI.Size = UDim2.fromOffset(presumedSize * scalar, presumedSize * scalar)
			presumedUI.Position += offsetPos
		end
	end
end

--- Verifica e ajusta tamanho de todos os botÃµes baseado na resoluÃ§Ã£o
local function checkSizeContext()
	local minAxis = math.min(workspace.CurrentCamera.ViewportSize.X, workspace.CurrentCamera.ViewportSize.Y)
	local presumedSize = 120

	-- Ajusta tamanho do indicador principal
	if minAxis >= 600 then
		presumedSize = 220
	end

	if localPlayer:GetAttribute("Mobile") == true then
		indicatorMain.Size = UDim2.fromOffset(presumedSize, 0)
	end

	-- Redimensiona botÃµes de todos os contextos
	for i, v in InputSystem.Contexts do
		local context = v :: InputContext
		coroutine.wrap(resizeButtons)(context)
	end
end

-- Inicializa tamanhos e conecta ao evento de mudanÃ§a de viewport
coroutine.wrap(checkSizeContext)()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	if mobileUI.Enabled then
		coroutine.wrap(checkSizeContext)()
	end
end)

--// ============================================================================
--// SETOR: Retorno do MÃ³dulo
--// ============================================================================

return InputSystem

