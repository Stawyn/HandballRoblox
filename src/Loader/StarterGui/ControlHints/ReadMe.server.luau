-- Created and maintained by ZurichBT (Roblox username)
-- Control Hints: Show Your IAS Bindings (PC, Xbox, PlayStation, Mobile)
-- Integrates with Input Action System (IAS) to generate pretty control hints with icons for PC, Xbox, PlayStation, and Mobile.
-- Works with the standard IAS setup (Context → Action → Binding)


-- https://devforum.roblox.com/t/control-hints-show-your-ias-bindings-pc-xbox-playstation-mobile/3978604


-- How to Setup:
--   • See the 'TestMe' LocalScript.
-----   • Parent to StarterGui.
-----   • Set IAS_FOLDER to a Folder containing your IAS setup.
--   • Done!


-- Customization Tips:
--   • Update your preferences in 'Settings' ModuleScript, found under the main module.
--   • The names of InputBindings must start with 'Keyboard', 'Gamepad', or 'Mobile'.
--   • InputActions can have a CustomName attribute (string) to override InputAction.Name
--   • Each display style (ScreenGui) must contain:
-----   • 'HintsFrame' Frame containing:
--------   • 'HintTemplate' Frame containing:
-----------   • 'Icon' ImageLabel (can be nested)
-----------   • 'Label' TextLabel (can be nested)
-----------   • 'Separator' GuiObject (can be nested) (optional)
--   • Icon, Label, and Separator can be nested within HintTemplate, but must remain separate from each other.
--   • For multi-key actions, the module duplicates the icon or its container (and separator if present) using LayoutOrder offsets starting from the original icon's LayoutOrder or its container's LayoutOrder.
-----   • Tweak Settings.INCREMENT to change how the LayoutOrder is configured for cloned elements.
--   • If you'd like to borrow icons from the module, use the method ControlHints:GetIconId() to grab icon asset IDs for a given keycode, platform, and whatnot.