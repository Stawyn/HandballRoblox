--[[
	================================================================================
	SCRIPT: Loader
	================================================================================
	
	Descrição:
		Script principal de carregamento do projeto ABH.
		Responsável por distribuir os módulos e scripts para seus respectivos 
		serviços (ReplicatedStorage, ServerScriptService, etc.) durante a inicialização.
	
	Funcionalidades:
		- Itera sobre os filhos do script Loader.
		- Move cada pasta para o serviço de mesmo nome no jogo.
		- Tratamento especial para StarterPlayer e seus sub-diretórios.
		- Tratamento especial para Estádio em modo Studio.
		- Proteção contra pastas inválidas (ex: MainModule de admins).
	
	Autor: Sistema ABH
	================================================================================
]]

--// ============================================================================
--// SETOR: Serviços
--// ============================================================================

local StarterPlayer = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")

--// ============================================================================
--// SETOR: Configuração de Ambiente (SETUP CORE)
--// ============================================================================

print(">>> [LOADER] PREPARANDO AMBIENTE (CORE/DATA) <<<")

local function ensureFolder(parent, name)
	if not parent then return nil end
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
		print("[LOADER-SETUP] Criada pasta: " .. name)
	end
	return folder
end

local function ensureBoolValue(parent, name, defaultValue)
	if not parent then return nil end
	local val = parent:FindFirstChild(name)
	if not val then
		val = Instance.new("BoolValue")
		val.Name = name
		val.Value = defaultValue
		val.Parent = parent
		print("[LOADER-SETUP] Criado valor: " .. name)
	end
	return val
end

-- Garante estrutura crítica ANTES de carregar scripts
local core = ensureFolder(workspace, "Core")
local data = ensureFolder(core, "Data")
local balls = ensureFolder(core, "Balls")
local glt = ensureFolder(core, "GLT")

ensureBoolValue(data, "MatchPaused", false)
ensureBoolValue(data, "GameActive", false)

--// ============================================================================
--// SETOR: Lógica de Carregamento (DEBUG ATIVADO)
--// ============================================================================

print(">>> [LOADER] INICIANDO CARREGAMENTO DE MÓDULOS <<<")

-- Itera sobre todos os filhos deste script (pastas que representam serviços)
local children = script:GetChildren()
print("[LOADER] Filhos encontrados: " .. #children)

for _, pasta in pairs(children) do
	print("[LOADER] Processando pasta: " .. pasta.Name)
	
	-- Tenta obter o serviço correspondente
	local sucesso, servico = pcall(function()
		return game:GetService(pasta.Name)
	end)
	
	if not sucesso or not servico then
		warn("[LOADER] ERRO: '" .. pasta.Name .. "' não é um serviço válido ou falhou ao carregar.")
		continue
	else
		print("[LOADER] Serviço alvo encontrado: " .. pasta.Name)
	end
	
	-- Tratamento Especial: StarterPlayer
	if pasta.Name == "StarterPlayer" then
		print("[LOADER] Tratando StarterPlayer...")
		local starterPlayerScripts = pasta:FindFirstChild("StarterPlayerScripts")
		local starterCharacterScripts = pasta:FindFirstChild("StarterCharacterScripts")
		
		if starterPlayerScripts then
			print("[LOADER] Movendo StarterPlayerScripts (" .. #starterPlayerScripts:GetChildren() .. " itens)")
			for _, item in pairs(starterPlayerScripts:GetChildren()) do
				item.Parent = StarterPlayer.StarterPlayerScripts
			end
		end
		
		if starterCharacterScripts then
			print("[LOADER] Movendo StarterCharacterScripts (" .. #starterCharacterScripts:GetChildren() .. " itens)")
			for _, item in pairs(starterCharacterScripts:GetChildren()) do
				item.Parent = StarterPlayer.StarterCharacterScripts
			end
		end
	else
		-- Tratamento Padrào
		local itens = pasta:GetChildren()
		print("[LOADER] Movendo " .. #itens .. " itens para " .. servico.Name)
		for _, item in pairs(itens) do
			item.Parent = servico
		end
	end
end

--// ============================================================================
--// SETOR: Configuração de Ambiente (Studio)
--// ============================================================================

if RunService:IsStudio() then
	local stadium = workspace:FindFirstChild("Stadium")
	if stadium then
		print("[LOADER] Movendo Stadium para ReplicatedStorage (Studio Mode)")
		stadium.Parent = game:GetService("ReplicatedStorage")
	end
end

print(">>> [LOADER] CARREGAMENTO CONCLUÍDO <<<")

-- Sinaliza que o Loader terminou de mover todos os arquivos
local loaderReady = Instance.new("BoolValue")
loaderReady.Name = "LoaderReady"
loaderReady.Value = true
loaderReady.Parent = game:GetService("ReplicatedStorage")
print("[LOADER] Sinalização LoaderReady criada em ReplicatedStorage")

-- O Loader cumpriu seu papel e pode ser destruído para limpar a hierarquia
-- script:Destroy() -- Descomentar em produção
