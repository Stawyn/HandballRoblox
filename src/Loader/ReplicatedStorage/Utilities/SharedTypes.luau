--[[
	================================================================================
	MÓDULO: SharedTypes
	================================================================================
	
	Descrição:
		Define os tipos compartilhados entre cliente e servidor.
		Usado para garantir type-safety e autocomplete em todo o projeto.
	
	Tipos Exportados:
		- ForceFieldInstance: Instà¢ncia do campo de força da bola
		- ABHBallInstance: Instà¢ncia completa da bola ABH
		- DirectionData: Dados de direção para arremessos
	
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
--// SETOR: Tipos de ForceField (Campo de Força)
--// ============================================================================

--[[
	ForceFieldInstance
	
	Representa o campo de força que protege a bola durante cobranças.
	Contém um timer visual e é usado para delimitar áreas de posse.
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
	Contém todas as informações de estado, física e visual.
	
	Information:
		- LastPlayerOnBall: àšltimo jogador que segurou a bola
		- LastThrow: Jogador que fez o último arremesso
		- LastLastThrow: Penúltimo jogador que arremessou (para assists)
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
--// SETOR: Tipos de Dados de Direção
--// ============================================================================

--[[
	DirectionData
	
	Dados enviados do cliente para o servidor durante um arremesso.
	Contém informações sobre a direção do personagem, mouse e posição.
	
	Usado para:
		- Calcular a trajetória da bola
		- Aplicar modificadores de poder
		- Verificar se o arremesso é válido
]]
export type DirectionData = { 
	humanoidRootPartDirection: vector,  -- Direção que o personagem está olhando
	mouseDirection: vector,              -- Direção do cursor/cà¢mera
	mousePosition: vector,               -- Posição do hit do mouse
	humanoidRootPartPosition: vector     -- Posição do HumanoidRootPart
}

return {}

