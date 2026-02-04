-- Created and maintained by ZurichBT (Roblox username)
-- Control Hints: Show Your IAS Bindings (PC, Xbox, PlayStation, Mobile)
-- Integrates with Input Action System (IAS) to generate pretty control hints with icons for PC, Xbox, PlayStation, and Mobile.
-- Works with the standard IAS setup (Context â†’ Action â†’ Binding)


-- https://devforum.roblox.com/t/control-hints-show-your-ias-bindings-pc-xbox-playstation-mobile/3978604


-- How to Setup:
--   â€¢ See the 'TestMe' LocalScript.
-----   â€¢ Parent to StarterGui.
-----   â€¢ Set IAS_FOLDER to a Folder containing your IAS setup.
--   â€¢ Done!


-- Customization Tips:
--   â€¢ Update your preferences in 'Settings' ModuleScript, found under the main module.
--   â€¢ The names of InputBindings must start with 'Keyboard', 'Gamepad', or 'Mobile'.
--   â€¢ InputActions can have a CustomName attribute (string) to override InputAction.Name
--   â€¢ Each display style (ScreenGui) must contain:
-----   â€¢ 'HintsFrame' Frame containing:
--------   â€¢ 'HintTemplate' Frame containing:
-----------   â€¢ 'Icon' ImageLabel (can be nested)
-----------   â€¢ 'Label' TextLabel (can be nested)
-----------   â€¢ 'Separator' GuiObject (can be nested) (optional)
--   â€¢ Icon, Label, and Separator can be nested within HintTemplate, but must remain separate from each other.
--   â€¢ For multi-key actions, the module duplicates the icon or its container (and separator if present) using LayoutOrder offsets starting from the original icon's LayoutOrder or its container's LayoutOrder.
-----   â€¢ Tweak Settings.INCREMENT to change how the LayoutOrder is configured for cloned elements.
--   â€¢ If you'd like to borrow icons from the module, use the method ControlHints:GetIconId() to grab icon asset IDs for a given keycode, platform, and whatnot.
