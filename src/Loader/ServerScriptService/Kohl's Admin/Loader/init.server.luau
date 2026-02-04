local Package = script.Parent

local DEMO_PLACE = 2569622788
local MAIN_MODULE_ID = 1868400649
local MAIN_MODULE_NAME = "MainModule"

local AUTO_UPDATE = false
local LEGACY = false

local CONFIG = Package:FindFirstChild("Config")
print(">>> [KOHLS-DEBUG] Loader Iniciado em: " .. script:GetFullName())
if CONFIG then
	AUTO_UPDATE = false -- CONFIG:GetAttribute("AutoUpdate")
	LEGACY = CONFIG:GetAttribute("Legacy")
	print("[KOHLS-DEBUG] Config encontrado. Legacy: " .. tostring(LEGACY))
else
	warn("[KOHLS-DEBUG] Config NÃO encontrado!")
end

if (LEGACY and not _G.KAU) or not shared._K_LOADER_LOADED then
	local legacyConfig = CONFIG:FindFirstChild("Legacy")

	if LEGACY then
		_G.KAU = true
		MAIN_MODULE_NAME = "MainModuleLegacy"
		for _, child in legacyConfig:GetChildren() do
			child.Parent = script
		end
		script.Name = "Kohl's Admin Infinite"
		script.Parent = game:GetService("ServerScriptService")
	else
		shared._K_LOADER_LOADED = true
		Package.Parent = game:GetService("ServerScriptService")
	end
	AUTO_UPDATE = AUTO_UPDATE and game.PlaceId ~= DEMO_PLACE

	local localMainModule = script:FindFirstChild(MAIN_MODULE_NAME) or MAIN_MODULE_ID
	print("[KOHLS-DEBUG] Tentando carregar MainModule: " .. tostring(localMainModule))
	if typeof(localMainModule) == "Instance" then
		print("[KOHLS-DEBUG] MainModule é uma Instância. ClassName: " .. localMainModule.ClassName)
		script:WaitForChild("Tools").Parent = localMainModule:FindFirstChild("Server") or localMainModule
	else
		print("[KOHLS-DEBUG] MainModule é ID (ou não encontrado localmente).")
	end

	local ok, result = pcall(require, if AUTO_UPDATE then MAIN_MODULE_ID else localMainModule)
	print("[KOHLS-DEBUG] Require executado. Sucesso: " .. tostring(ok))

	if not ok then
		warn("[KOHLS-DEBUG] Falha no Require! Razão: " .. tostring(result))
		if AUTO_UPDATE then
			local function loadModuleAsset(assetId: number)
				local asset = game:GetService("InsertService"):LoadAsset(assetId)
				local module = asset:FindFirstChild("MainModule", true)
				if module then
					return assert(require(module), ":LoadAsset() module returned invalid values!")
				end
				error(`Failed to find the source for {assetId}.`)
			end

			warn("Kohl's Admin failed to auto-update from MainModule, trying to load from asset\nReason:\t" .. result)
			ok, result = pcall(loadModuleAsset, 172732271)
			if not ok then
				warn("Kohl's Admin failed to auto-update from asset, loading from local package\nReason:\t" .. result)
				result = require(localMainModule)
			end
		else
			warn("Kohl's Admin failed to load from local package\nReason:\t" .. result)
		end
	end

	if not LEGACY then
		result.initialize(CONFIG)
	end
end


