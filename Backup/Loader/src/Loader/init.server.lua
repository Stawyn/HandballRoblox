local StarterPlayer = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")

for _, v in script:GetChildren() do
	local service = game:GetService(v.Name)
	
	if v.Name == "StarterPlayer" then
		-- O StarterPlayer precisa de um tratamento especial ao carregar os modulos
		-- Ambas as variáveisa baixo são consideradas para estarem definidas
		local starterPlayerScripts = v:FindFirstChild("StarterPlayerScripts") :: Folder
		local starterCharacterScripts = v:FindFirstChild("StarterCharacterScripts") :: Folder
		
		for _, w in starterPlayerScripts:GetChildren() do
			w.Parent = StarterPlayer.StarterPlayerScripts
		end
		
		for _, w in starterCharacterScripts:GetChildren() do
			w.Parent = StarterPlayer.StarterCharacterScripts
		end
	else
		-- Para o resto dos serviços nós os carregamos normalmente
		for _, w in v:GetChildren() do
			w.Parent = service
		end
	end
end

if RunService:IsStudio() then
	if workspace:FindFirstChild("Stadium") then
		workspace.Stadium.Parent = game:GetService("ReplicatedStorage")
	end
end

--print("AS SCRIPTS PRINCIPAIS/MÓDULOS CARREGARAM")
script:Destroy()