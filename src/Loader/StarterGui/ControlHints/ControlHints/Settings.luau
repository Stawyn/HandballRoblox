--!strict
-- Configuration settings for the ControlHints module.

local Settings = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utilities = ReplicatedStorage:WaitForChild("Utilities")


local ControlHints = script.Parent
local IconSets = ControlHints:WaitForChild("IconSets")
local DisplayStyles = ControlHints:WaitForChild("DisplayStyles")

Settings.ICON_SET = require(Utilities:WaitForChild("Kenney"))  -- Select a ModuleScript inside the IconSets folder to use as the active Control Hints icon set.
Settings.DISPLAY_STYLE = DisplayStyles:WaitForChild("Classic") -- Select a ScreenGui inside the DisplayStyles folder to use as the active Control Hints display style.

Settings.INCREMENT = 1  -- Adjusts LayoutOrder for multi-binding icons/separators; tweak for direction.
Settings.DEBUG = true -- Toggles detailed non-critical warnings; recommended if you are having issues.

-- (OPTIONAL)
-- Responsive icons provide visual feedback by switching to filled/active icons while an InputAction is Pressed.
--   â€¢ Use '_active' table variants in icon set when the input action is pressed/held
--   â€¢ Selected icon set must include '<platform>_active' tables
--   â€¢ Selected icon set must have 'supportsResponsive' boolean set to true (ex: iconSet.supportsResponsive = true)
--   â€¢ When an InputAction is Pressed or Released, call UpdateUI() with an InputAction alone for the second parameter (for better performance)
Settings.ENABLE_RESPONSIVE = true

-- (OPTIONAL)
-- Dynamic scaling makes it easier to read button hints for console users playing from a distance.
--   â€¢ Example: 1Ã— font/icon size at 1080px width â†’ 1.4Ã— font/icon size at 1920px width)
--   â€¢ Only active for gamepad (console) users
--   â€¢ Tweak settings below to ensure your display style scales appropriately
Settings.ENABLE_DYNAMIC_SCALING = true
Settings.MIN_SCREEN_WIDTH = 1080 -- When screen width > MIN_SCREEN_WIDTH, font/icon size begins scaling.
Settings.MAX_SCREEN_WIDTH = 1920 -- When screen width > MAX_SCREEN_WIDTH, font/icon size stops scaling.
Settings.BASE_FONT_SIZE = 16 -- ActionText font size when screen width â‰¤ MIN_SCREEN_WIDTH.
Settings.BASE_ICON_SIZE = 30 -- IconImage size when screen width â‰¤ MIN_SCREEN_WIDTH.
Settings.MAX_SCALE_FACTOR = 1.4 -- Final font/icon scale reached when screen width â‰¥ MAX_SCREEN_WIDTH.



-- error handling; ignore
assert(typeof(Settings.ICON_SET) == "table", "Settings.ICON_SET (icon set table) is missing!")
assert(typeof(Settings.DISPLAY_STYLE) == "Instance" and Settings.DISPLAY_STYLE:IsA("ScreenGui"), "Settings.DISPLAY_STYLE (ScreenGui) is missing!")
assert(typeof(Settings.INCREMENT) == "number", "Settings.INCREMENT (number) is missing!")
assert(typeof(Settings.DEBUG) == "boolean", "Settings.DEBUG (boolean) is missing!")
assert(typeof(Settings.ENABLE_RESPONSIVE) == "boolean", "Settings.ENABLE_RESPONSIVE (boolean) is missing!")
assert(typeof(Settings.ENABLE_DYNAMIC_SCALING) == "boolean", "Settings.ENABLE_DYNAMIC_SCALING (boolean) is missing!")
if Settings.ENABLE_DYNAMIC_SCALING then
	assert(typeof(Settings.BASE_FONT_SIZE) == "number", "[Dynamic Scaling] Settings.BASE_FONT_SIZE (number) is missing!")
	assert(typeof(Settings.BASE_ICON_SIZE) == "number", "[Dynamic Scaling] Settings.BASE_ICON_SIZE (number) is missing!")
	assert(typeof(Settings.MIN_SCREEN_WIDTH) == "number", "[Dynamic Scaling] Settings.MIN_SCREEN_WIDTH (number) is missing!")
	assert(typeof(Settings.MAX_SCREEN_WIDTH) == "number", "[Dynamic Scaling] Settings.MAX_SCREEN_WIDTH (number) is missing!")
	assert(typeof(Settings.MAX_SCALE_FACTOR) == "number", "[Dynamic Scaling] Settings.MAX_SCALE_FACTOR (number) is missing!")
end

return Settings
