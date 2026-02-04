--!nocheck
--[[
	================================================================================
	SCRIPT: Init (Cliente)
	================================================================================
	
	Descrição:
		Script de inicialização do lado do Cliente (LocalScript).
		Responsável por carregar módulos do sistema e configurar o personagem inicial.
	
	Localização:
		StarterPlayerScripts/Init
	
	Funcionalidades:
		- Carrega módulos em ReplicatedStorage/Modules/Systems.
		- Desabilita estados indesejados do Humanoid (Escalar, Pular).
		- Detecta tipo de dispositivo (Mobile/PC) e informa o servidor.
	
	Autor: Sistema ABH
	================================================================================
]]

--// ============================================================================
--// SETOR: Serviços
--// ============================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

--// ============================================================================
--// SETOR: Constantes e Referências
--// ============================================================================

local MODULES_FOLDER = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Systems")
local NETWORK_FOLDER = ReplicatedStorage:WaitForChild("Network")
local PLAYER_DATA_FOLDER = NETWORK_FOLDER:WaitForChild("PlayerData")

local localPlayer = Players.LocalPlayer

--// ============================================================================
--// SETOR: Carregamento de Módulos
--// ============================================================================

-- Itera e carrega todos os ModuleScripts na pasta de sistemas
for _, module in MODULES_FOLDER:GetChildren() do
	if module:IsA("ModuleScript") then
		require(module)
	end
end

--// ============================================================================
--// SETOR: Inicialização de UI para Officials (AntiHack)
--// ============================================================================

-- Carrega UI de alertas anti-hack (funciona para todos, mas só Officials recebem alertas)
local AntiHackUI = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Implementation"):WaitForChild("AntiHackUI"))
AntiHackUI:Init()

--// ============================================================================
--// SETOR: Funções Auxiliares
--// ============================================================================

--[[
	Configura o personagem quando ele é adicionado.
	Desabilita estados de movimento não desejados para este jogo.
	
	@param character Model - O modelo do personagem do jogador
]]
local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid

	-- Desabilita escalada e pulo (pulo é controlado pelo Stamina system)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
end

--[[
	Detecta o dispositivo do jogador e envia para o servidor.
	Utilizado para exibir ícone correspondente (Celular/PC).
]]
local function detectAndSendDevice()
	local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	local deviceEmoji = if isMobile then "📱" else "🖥️"

	-- Tenta encontrar o evento remoto, aguardando se necessário
	local setDevice = PLAYER_DATA_FOLDER:FindFirstChild("SetDevice")
	if not setDevice then
		setDevice = PLAYER_DATA_FOLDER:WaitForChild("SetDevice", 10)
	end

	if setDevice and setDevice:IsA("RemoteEvent") then
		setDevice:FireServer(deviceEmoji)
	end
end

--// ============================================================================
--// SETOR: Inicialização
--// ============================================================================

-- Detecção de dispositivo em thread separada para não bloquear
task.spawn(detectAndSendDevice)

-- Configuração do personagem (atual e futuros)
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
coroutine.wrap(onCharacterAdded)(character)

localPlayer.CharacterAdded:Connect(onCharacterAdded)
