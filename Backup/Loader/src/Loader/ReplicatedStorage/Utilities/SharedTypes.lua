type Timer = {
	Seconds: TextLabel
} & BillboardGui

export type ForceFieldInstance = {
	Timer: Timer,
} & BasePart

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

export type DirectionData = { 
	humanoidRootPartDirection: vector,
	mouseDirection: vector,
	mousePosition: vector,
	humanoidRootPartPosition: vector
}

return {}