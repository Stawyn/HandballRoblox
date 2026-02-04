--[[
    ================================================================================
    SCRIPT: Init.client
    ================================================================================
    Descricao: Script de inicializacao do cliente - carrega modulos e configura
               personagem.
    
    Funcionalidades:
        - Carrega todos os ModuleScripts de ReplicatedStorage/Modules/Systems
        - Desabilita estados de humanoid (Climbing, Jumping)
        - Detecta dispositivo (Mobile/PC) e envia ao servidor
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: SERVICOS
--// ============================================================================

--!nocheck
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

--// ============================================================================
--// SETOR: REFERENCIAS
--// ============================================================================

local modules = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Systems")
local localPlayer = Players.LocalPlayer

--// ============================================================================
--// SETOR: CARREGAMENTO DE MODULOS
--// ============================================================================

for _, v in modules:GetChildren() do
	if v:IsA("ModuleScript") then
		require(v)
	end
end

--// ============================================================================
--// SETOR: CONFIGURACAO DE PERSONAGEM
--// ============================================================================

--- Configura estados do humanoid ao personagem ser adicionado
local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid

	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
end

--// ============================================================================
--// SETOR: DETECCAO DE DISPOSITIVO
--// ============================================================================

task.spawn(function()
	local GuiService = game:GetService("GuiService")
	
	-- Detecção de mobile melhorada:
	-- 1. Tem touch
	-- 2. Não tem teclado físico (apenas teclado virtual)
	-- 3. Não é console (ten-foot interface)
	local isMobile = UserInputService.TouchEnabled 
		and not UserInputService.KeyboardEnabled 
		and not GuiService:IsTenFootInterface()
	
	local deviceEmoji = if isMobile then "📱" else "🖥️"

	local network = ReplicatedStorage:WaitForChild("Network")
	local playerData = network:WaitForChild("PlayerData")
	local setDevice = playerData:FindFirstChild("SetDevice")
	
	if not setDevice then
		setDevice = playerData:WaitForChild("SetDevice", 10)
	end

	if setDevice and setDevice:IsA("RemoteEvent") then
		setDevice:FireServer(deviceEmoji)
	end
end)

--// ============================================================================
--// SETOR: CONEXOES
--// ============================================================================

local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
coroutine.wrap(onCharacterAdded)(character)
localPlayer.CharacterAdded:Connect(onCharacterAdded)
