--[[
	================================================================================
	SCRIPT: SetupCore (Auto-Repair)
	================================================================================
	
	Descrição:
		Garante que a estrutura física necessária em Workspace.Core exista.
		Cria pastas e valores essenciais se estiverem faltando, evitando Infinite Yield.
	
	Autor: Sistema ABH (Setup Automático)
	================================================================================
]]

local Workspace = game:GetService("Workspace")

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
		print("[SetupCore] Criada pasta faltando: " .. name)
	end
	return folder
end

local function ensureBoolValue(parent, name, defaultValue)
	local val = parent:FindFirstChild(name)
	if not val then
		val = Instance.new("BoolValue")
		val.Name = name
		val.Value = defaultValue
		val.Parent = parent
		print("[SetupCore] Criado valor faltando: " .. name)
	end
	return val
end

-- Garante estrutura principal
local core = ensureFolder(Workspace, "Core")
local data = ensureFolder(core, "Data")
local balls = ensureFolder(core, "Balls")
local glt = ensureFolder(core, "GLT")

-- Garante valores críticos que travam scripts se faltarem
ensureBoolValue(data, "MatchPaused", false) -- Começa não pausado
ensureBoolValue(data, "GameActive", false)

print("[SetupCore] Verificação de ambiente concluída.")
