return function(_K)
	local KIT_DEFS = {
		resers = { shirt = 115211738134175, shorts = 127546883599111 },
		coca = { shirt = 111683000154462, shorts = 107506477318921 },
		cpm = { shirt = 119955908210509, shorts = 117699941839592 },
		cpm2 = { shirt = 138594920777943, shorts = 74875336504804 },
		gelerme = { shirt = 123957247191952, shorts = 118208929781674 },
		denos = { shirt = 128454071930027, shorts = 134026662132098 },
		xxwhite = { shirt = 128454071930027, shorts = 134026662132098 },
	}

	local function setKit(player, kitName)
		local kit = KIT_DEFS[kitName]
		if not kit then return end
		local character = player.Character
		if not character then return end

		player:SetAttribute("UsingCustomKit", true)

		-- Resolve os templates reais antes de aplicar (converte ID do produto para ID da imagem)
		local shirtTemplate = _K.Util.getTexture(kit.shirt)
		local pantsTemplate = _K.Util.getTexture(kit.shorts)

		-- Limpa roupas atuais
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
				child:Destroy()
			end
		end

		-- Cria Shirt se o template foi resolvido
		if shirtTemplate then
			local shirt = Instance.new("Shirt")
			shirt.Name = "KShirt"
			shirt.ShirtTemplate = shirtTemplate
			shirt.Parent = character
		end

		-- Cria Pants se o template foi resolvido
		if pantsTemplate then
			local pants = Instance.new("Pants")
			pants.Name = "KPants"
			pants.PantsTemplate = pantsTemplate
			pants.Parent = character
		end

		return true
	end

	_K.Registry.registerCommand(_K, {
		name = "kit",
		aliases = { "setkit" },
		description = "Dá o kit para o jogador ou time.",
		group = "Admin",
		args = {
			{
				name = "kitName",
				type = "string",
				description = "Nome do kit (resers, coca, cpm, cpm2, gelerme, denos, xxwhite)",
			},
			{
				name = "target",
				type = "players",
				description = "Jogador(es) ou time",
				optional = true,
			},
		},
		run = function(context, kitName, targets)
			kitName = kitName:lower()
			if not KIT_DEFS[kitName] then
				return "Kit não encontrado: " .. kitName
			end

			local players = targets
			if not players or #players == 0 then
				players = {context.fromPlayer}
			end

			for _, p in ipairs(players) do
				setKit(p, kitName)
			end

			return "Kit '" .. kitName .. "' aplicado a " .. #players .. " jogador(es)."
		end,
	})
end

