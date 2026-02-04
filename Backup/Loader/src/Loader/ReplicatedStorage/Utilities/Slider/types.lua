--!strict

export type Values = {
	min: number,
	max: number,
}

export type Properties = {
	step: number,
	xboxStep: number,
	canLeaveFrame: boolean,
	canFullyLeaveFrame: boolean,
	moveToMouse: boolean,
	waypoints: { Waypoint },
	trackers: { Tracker },
	values: Values,
	defaultValue: number,
	axis: "X" | "Y",
}

export type RoundFunction = (n: number) -> string
export type TextMakerFunction = (_string: string) -> string

export type Tracker = {
	Enable: (self: Tracker) -> nil,
	Disable: (self: Tracker) -> nil,
	SetSlider: (self: Tracker, slider: Slider) -> nil,
	SetLabel: (self: Tracker, label: TextLabel) -> nil
}

export type Waypoint = {
	SetPosition: (self: Waypoint, position: UDim2) -> nil,
	SetGuiObject: (self: Waypoint, frame: GuiObject) -> nil,
	
	Show: (self: Waypoint) -> nil,
	Hide: (self: Waypoint) -> nil,
	Remove: (self: Waypoint) -> nil,
	
	entered: Signal,
	leaved: Signal
}

type PublicSignal<T, F> = {
	Connect: (self: T, callback: F) -> nil,
	Disconnect: (self: T) -> nil
}

export type Signal = PublicSignal<Signal, (...any) -> (...any)> & {
	Fire: (self: Signal, ...any) -> nil,
}

export type MovedSignal = PublicSignal<MovedSignal, (isForced: boolean) -> nil>
export type WaypointEnteredSignal = PublicSignal<WaypointEnteredSignal, (waypoint: Waypoint) -> nil>
export type WaypointLeavedSignal = PublicSignal<WaypointLeavedSignal, (waypoint: Waypoint) -> nil>

export type Slider = {
	Enable: (self: Slider, widget: PluginGui?) -> (),
	Disable: (self: Slider) -> (),
	Reset: (self: Slider) -> (),
	
	SetPluginMouse: (self: Slider, plugin: Plugin) -> (),
	
	SetStep: (self: Slider, n: number) -> (),
	GetStep: (self: Slider) -> number, 
	
	--SetPosition: (self: Slider, position: UDim2, forced: boolean, frame: GuiObject?) -> (),
	
	GetValue: (self: Slider, usePercentage: boolean?) -> number,
	SetValue: (self: Slider, value: number, isPercentage: boolean?) -> (),
	
	SetValues: (self: Slider, values: Values) -> (),
	GetValues: (self: Slider) -> Values,
	
	AddWaypoint: (self: Slider, n: number, isPercentage: boolean?) -> Waypoint,
	RemoveWaypoint: (self: Slider, n: number) -> (),
	ShowWaypoint: (self: Slider, n: number) -> (),
	HideWaypoint: (self: Slider, n: number) -> (),
	ShowWaypoints: (self: Slider) -> (),
	HideWaypoints: (self: Slider) -> (),
	
    AddTracker: (
        self: Slider,
        label: TextLabel,
        roundFunction: RoundFunction?,
        textMakerFunction: TextMakerFunction?
    ) -> Tracker,
	RemoveTracker: (self: Slider, tracker: Tracker) -> (),
	EnableTracker: (self: Slider, tracker: Tracker) -> (),
	DisableTracker: (self: Slider, tracker: Tracker) -> (),
	EnableTrackers: (self: Slider) -> (),
	DisableTrackers: (self: Slider) -> (),
	
	moved: MovedSignal,
	waypointEntered: WaypointEnteredSignal,
	waypointLeaved: WaypointLeavedSignal,
	
	--roundPercentage: number,
}

return nil
