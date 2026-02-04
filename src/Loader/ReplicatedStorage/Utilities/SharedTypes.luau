--[[
    ================================================================================
    MÓDULO: SharedTypes
    ================================================================================
    Descrição: Definições de tipos compartilhados entre cliente e servidor.
               Centraliza todas as interfaces de dados do projeto ABH.
    
    Tipos Exportados:
        - ABHBallInstance: Estrutura completa da bola
        - ForceFieldInstance: Campo de força com timer
        - DirectionData: Dados de direção para arremesso
        - PlayerStats: Estatísticas de jogador
        - MatchState: Estado atual da partida
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: TIPOS AUXILIARES
--// ============================================================================

--- Timer visual da bola (BillboardGui)
type Timer = {
	Seconds: TextLabel
} & BillboardGui

--// ============================================================================
--// SETOR: TIPOS DE INSTÂNCIAS
--// ============================================================================

--- Instância do ForceField da bola
export type ForceFieldInstance = {
	Timer: Timer,
} & BasePart

--- Instância completa da bola ABH
-- @field Information Folder - Contém dados de posse e estado
-- @field Timer Timer - Timer visual
-- @field Trail Trail - Rastro visual
-- @field ResistanceForce VectorForce - Força de arrasto
-- @field ForceField ForceFieldInstance - Campo de proteção
-- @field RefereeImmunity BoolValue - Imunidade de árbitro
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
--// SETOR: TIPOS DE DADOS
--// ============================================================================

--- Dados de direção para arremesso
-- @field humanoidRootPartDirection vector - Direção do HRP
-- @field mouseDirection vector - Direção do mouse
-- @field mousePosition vector - Posição do mouse no mundo
-- @field humanoidRootPartPosition vector - Posição do HRP
export type DirectionData = { 
	humanoidRootPartDirection: vector,
	mouseDirection: vector,
	mousePosition: vector,
	humanoidRootPartPosition: vector
}

--- Estatísticas de jogador
export type PlayerStats = {
	Goals: number,
	Assists: number,
	Saves: number,
	Steals: number,
	Shots: number,
	SOG: number,
	Turnovers: number,
	PassesCompleted: number,
	PassesFailed: number,
	PossessionTime: number,
	Rating: number?,
	EficPct: number?,
}

--- Estado da partida
export type MatchState = {
	IsActive: boolean,
	IsPaused: boolean,
	CurrentHalf: number,
	HomeScore: number,
	AwayScore: number,
	Timer: number,
	HomeName: string,
	AwayName: string,
}

--- Lado do time
export type TeamSide = "Home" | "Away" | "Officials" | "Lobby" | "Unknown"

return {}