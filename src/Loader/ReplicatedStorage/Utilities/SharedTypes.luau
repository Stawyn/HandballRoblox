--[[
	================================================================================
	MÃ“DULO: SharedTypes
	================================================================================
	
	DescriÃ§Ã£o:
		Define os tipos compartilhados entre cliente e servidor.
		Usado para garantir type-safety e autocomplete em todo o projeto.
	
	Tipos Exportados:
		- ForceFieldInstance: InstÃ¢ncia do campo de forÃ§a da bola
		- ABHBallInstance: InstÃ¢ncia completa da bola ABH
		- DirectionData: Dados de direÃ§Ã£o para arremessos
	
	Autor: Sistema ABH
	================================================================================
]]

--// ============================================================================
--// SETOR: Tipos de Timer
--// ============================================================================

--- Timer visual que mostra os segundos restantes
type Timer = {
	Seconds: TextLabel
} & BillboardGui

--// ============================================================================
--// SETOR: Tipos de ForceField (Campo de ForÃ§a)
--// ============================================================================

--[[
	ForceFieldInstance
	
	Representa o campo de forÃ§a que protege a bola durante cobranÃ§as.
	ContÃ©m um timer visual e Ã© usado para delimitar Ã¡reas de posse.
]]
export type ForceFieldInstance = {
	Timer: Timer,
} & BasePart

--// ============================================================================
--// SETOR: Tipos de Bola (ABHBall)
--// ============================================================================

--[[
	ABHBallInstance
	
	Estrutura completa de uma bola no jogo ABH.
	ContÃ©m todas as informaÃ§Ãµes de estado, fÃ­sica e visual.
	
	Information:
		- LastPlayerOnBall: Ãšltimo jogador que segurou a bola
		- LastThrow: Jogador que fez o Ãºltimo arremesso
		- LastLastThrow: PenÃºltimo jogador que arremessou (para assists)
		- CurrentPlayerOnBall: Jogador atual segurando a bola
		- CanTackle: Se a bola pode ser roubada
		- Timer: Tempo restante de posse
]]
export type ABHBallInstance = {
	Information: {
		LastPlayerOnBall: ObjectValue,
		LastThrow: ObjectValue,
		LastLastThrow: ObjectValue,
		CurrentPlayerOnBall: ObjectValue,
		CanTackle: BoolValue,
		Timer: NumberValue
	} & Folder,
	Timer: Timer,
	Trail: Trail,
	ResistanceForce: VectorForce,
	SpecialMesh: SpecialMesh,
	ForceField: ForceFieldInstance,
	RefereeImmunity: BoolValue
} & MeshPart

--// ============================================================================
--// SETOR: Tipos de Dados de DireÃ§Ã£o
--// ============================================================================

--[[
	DirectionData
	
	Dados enviados do cliente para o servidor durante um arremesso.
	ContÃ©m informaÃ§Ãµes sobre a direÃ§Ã£o do personagem, mouse e posiÃ§Ã£o.
	
	Usado para:
		- Calcular a trajetÃ³ria da bola
		- Aplicar modificadores de poder
		- Verificar se o arremesso Ã© vÃ¡lido
]]
export type DirectionData = { 
	humanoidRootPartDirection: vector,  -- DireÃ§Ã£o que o personagem estÃ¡ olhando
	mouseDirection: vector,              -- DireÃ§Ã£o do cursor/cÃ¢mera
	mousePosition: vector,               -- PosiÃ§Ã£o do hit do mouse
	humanoidRootPartPosition: vector     -- PosiÃ§Ã£o do HumanoidRootPart
}

return {}

