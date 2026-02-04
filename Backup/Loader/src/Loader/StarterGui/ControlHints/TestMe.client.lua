--!strict
--!native

-- Place in StarterGui.
-- Automatically creates and updates Control Hints UI using IAS_FOLDER.
-- Cleans up old UI instances on load and handles respawn/reset.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player.PlayerGui

-- === Configuration ==============================================================
local IAS_FOLDER = player:WaitForChild("InputSystem", math.huge) -- Path to a Folder containing your IAS setup.
local CONTROL_HINTS = script.Parent.ControlHints -- Path to the Control Hints main module.
local UI_TAG = "ControlHintsUI"   -- Tag used to identify & remove old UI (you can leave this alone).
-- More settings found in the 'Settings' ModuleScript under the Control Hints module.
-- ============================================================================



local ContextFolder = IAS_FOLDER
local ControlHints = require(CONTROL_HINTS)
local Settings = require(CONTROL_HINTS:WaitForChild("Settings"))
local contextFolder: Folder?
local myIAS: {[InputContext]: {InputAction}} = {}
local myUI: ScreenGui?
local connections: {[Instance]: {RBXScriptConnection}} = {}

-- Collects all enabled InputContexts and their InputActions from the target folder
local function collectIAS(): {[InputContext]: {InputAction}}
	local result: {[InputContext]: {InputAction}} = {}
	if not ContextFolder then return result end

	for _, child in ContextFolder:GetChildren() do
		if child:IsA("InputContext") then
			local actions: {InputAction} = {}
			for _, sub in child:GetChildren() do
				if sub:IsA("InputAction") then
					table.insert(actions, sub)
				end
			end
			result[child] = actions
		end
	end
	return result
end

-- Sets up Changed signal on a single InputContext
local function setupContextConn(context: InputContext)
	local conns = connections[context] or {}

	conns[#conns + 1] = context.Changed:Connect(function()
		if myUI then
			ControlHints:UpdateUI(myUI, myIAS) -- full update on context property change
		end
	end)

	connections[context] = conns
end

-- Sets up Changed / Pressed / Released signals on a single InputAction
local function setupActionConn(action: InputAction)
	local function process()
		if myUI and action:FindFirstAncestorOfClass("InputContext") then
			ControlHints:UpdateUI(myUI, action) -- partial update
		end
	end

	local conns = connections[action] or {}

	conns[#conns + 1] = action.Changed:Connect(process)

	if Settings.ENABLE_RESPONSIVE then
		conns[#conns + 1] = action.Pressed:Connect(process)
		conns[#conns + 1] = action.Released:Connect(process)
	end

	connections[action] = conns
end

-- Disconnects old listeners, recollects IAS, reconnects, and refreshes or creates UI
local function refreshConnections()
	-- Disconnect everything first
	for _, conns in connections do
		for _, conn in conns do
			if conn.Connected then
				conn:Disconnect()
			end
		end
	end
	table.clear(connections)

	-- Re-collect current IAS state
	table.clear(myIAS)
	myIAS = collectIAS()

	-- Reconnect signals
	for context, actions in myIAS do
		setupContextConn(context)
		for _, action in actions do
			setupActionConn(action)
		end
	end

	-- Update or create UI
	local hasContexts = next(myIAS) ~= nil
	if hasContexts then
		if not myUI then
			local newUI = ControlHints:CreateUI(playerGui)
			CollectionService:AddTag(newUI, UI_TAG)
			myUI = newUI
		end
		ControlHints:UpdateUI(myUI :: ScreenGui, myIAS) -- full update
	elseif myUI then
		myUI:Destroy()
		myUI = nil
	end
end

-- Unified handler for DescendantAdded / DescendantRemoving
local function onDescendantChange(desc: Instance, _isAdding: boolean)
	if desc:IsA("InputContext") or desc:IsA("InputAction") then
		refreshConnections()
	end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Main initialization
-- ──────────────────────────────────────────────────────────────────────────────

-- Clean up any leftover UI from previous script instances / respawns
for _, obj in CollectionService:GetTagged(UI_TAG) do
	obj:Destroy()
end

-- Initial refresh + live update connections
refreshConnections()

ContextFolder.DescendantAdded:Connect(function(desc)
	onDescendantChange(desc, true)
end)

ContextFolder.DescendantRemoving:Connect(function(desc)
	onDescendantChange(desc, false)
end)

-- connections[ContextFolder] = {addConn, removeConn}