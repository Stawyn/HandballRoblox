local KeybindInit = {}
local mobileBase = script.MobileBase

local SetPieceDefault = {
	["Spawn"] = {
		["Keyboard"] = Enum.KeyCode.MouseLeftButton.Name,
		["Controller"] = Enum.KeyCode.DPadRight.Name,
		["Scalar"] = 1,
		["MobOffset"] = {0,0}

	},
	["Change Team"] = {
		["Keyboard"] = Enum.KeyCode.MouseRightButton.Name,
		["Controller"] = Enum.KeyCode.DPadUp.Name,
		["Scalar"] = 1,
		["MobOffset"] = {0,0}
	}
}

local SetPieceButtons = {
	["Spawn"] = mobileBase.Special2,
	["Change Team"] = mobileBase.Special1
}

local ActionsButtons = {
	["Goalkeeper"] = {
		["Left Predict"] = mobileBase.Frame2,
		["Right Predict"] = mobileBase.Frame3
	},
	["Physical"] = {
		["Sprint"] = mobileBase.Sprint
	},
	["Hands"] = {
		["Switch Hand"] = mobileBase["Switch Hand"]
	},
	["Referee General"] = {
		["Remove balls"] = mobileBase.Special3
	},
	["Throw Tool"] = {
		["Fake Throw"] = mobileBase.Frame1,
		["Throw"] = mobileBase.Frame2,
		["Tackle"] = mobileBase.Frame3
	},
	["Spawn Tool"] = {
		["Spawn"] = mobileBase.Special1,
		["Remove balls"] = mobileBase.Special2
	},
	["Set Piece Tool"] = SetPieceButtons,
	["Penalty Tool"] = SetPieceButtons
}

KeybindInit.DefaultActions = {
	["Goalkeeper"] = {
		["Left Predict"] = {
			["Keyboard"] = Enum.KeyCode.MouseLeftButton.Name,
			["Controller"] = Enum.KeyCode.ButtonL2.Name,
			["Scalar"] = 1,
			["MobOffset"] = {0,0}
		},
		["Right Predict"] = {
			["Keyboard"] = Enum.KeyCode.MouseRightButton.Name,
			["Controller"] = Enum.KeyCode.ButtonR2.Name,
			["Scalar"] = 1,
			["MobOffset"] = {0,0}
		}
	},
	["Physical"] = {
		["Sprint"] = {
			["Keyboard"] = Enum.KeyCode.LeftControl.Name,
			["Controller"] = Enum.KeyCode.ButtonR1.Name,
			["Scalar"] = 1,
			["MobOffset"] = {0,0}
		}
	},
	["Throw Tool"] = {
		["Fake Throw"] = {
			["Keyboard"] = Enum.KeyCode.R.Name,
			["Controller"] = Enum.KeyCode.ButtonY.Name,
			["Scalar"] = 1,
			["MobOffset"] = {0,0}

		},
		["Throw"] = {
			["Keyboard"] = Enum.KeyCode.MouseLeftButton.Name,
			["Controller"] = Enum.KeyCode.ButtonX.Name,
			["Scalar"] = 1,
			["MobOffset"] = {0,0}

		},
		["Tackle"] = {
			["Keyboard"] = Enum.KeyCode.MouseRightButton.Name,
			["Controller"] = Enum.KeyCode.ButtonB.Name,
			["Scalar"] = 1,
			["MobOffset"] = {0,0}
		}
	},
	["Hands"] = {
		["Switch Hand"] = {
			["Keyboard"] = Enum.KeyCode.F.Name,
			["Controller"] = Enum.KeyCode.ButtonA.Name,
			["Scalar"] = 1,
			["MobOffset"] = {0,0}
		},
	},
	["Referee General"] = {
		["Remove balls"] = {
			["Keyboard"] = Enum.KeyCode.T.Name,
			["Controller"] = Enum.KeyCode.ButtonR3.Name,
			["Scalar"] = 1,
			["MobOffset"] = {0,0}

		}
	},
	["Spawn Tool"] = {
		["Spawn"] = {
			["Keyboard"] = Enum.KeyCode.MouseLeftButton.Name,
			["Controller"] = Enum.KeyCode.DPadDown.Name,
			["Scalar"] = 1,
			["MobOffset"] = {0,0}

		},
		["Remove balls"] = {
			["Keyboard"] = Enum.KeyCode.T.Name,
			["Controller"] = Enum.KeyCode.ButtonR3.Name,
			["Scalar"] = 1,
			["MobOffset"] = {0,0}
		}
	},
	["Set Piece Tool"] = SetPieceDefault,
	["Penalty Tool"] = SetPieceDefault,
	["General"] = {
		["Shiftlock"] = {
			["Keyboard"] = Enum.KeyCode.LeftShift.Name,
			["Scalar"] = 1,
			["MobOffset"] = {0,0}
		}
	}
}

function KeybindInit:Start(player: Player, data: typeof(KeybindInit.DefaultActions))
	local mobileUI = player.PlayerGui:WaitForChild("Mobile")
	local keybinds = Instance.new("Folder")
	keybinds.Name = "InputSystem"

	for context, actionList in data do
		local inputContext = Instance.new("InputContext")
		inputContext.Name = context
		inputContext.Enabled = false

		for actionName, actionKeybinds in actionList do
			local inputAction = Instance.new("InputAction")
			inputAction.Name = actionName
			inputAction.Type =  Enum.InputActionType.Bool

			local inputBinding = Instance.new("InputBinding")
			inputBinding.KeyCode = Enum.KeyCode[actionKeybinds.Keyboard]
			inputBinding.Name = "Keyboard"
			inputBinding.Parent = inputAction

			if actionKeybinds.Controller then
				local controllerBinding = Instance.new("InputBinding")
				controllerBinding.KeyCode = Enum.KeyCode[actionKeybinds.Controller]
				controllerBinding.Name = "Gamepad"
				controllerBinding.Parent = inputAction
			end

			if ActionsButtons[context] and ActionsButtons[context][actionName] then
				local presumedFrame = ActionsButtons[context][actionName]:Clone() :: Frame
				presumedFrame.Name = actionName
				presumedFrame.Interact.Text = actionName


				local scalar = data[context][actionName]["Scalar"]
				presumedFrame:SetAttribute("Context", context)
				presumedFrame:SetAttribute("PresumedSize", 40)
				presumedFrame:SetAttribute("PosOffsetX", data[context][actionName]["MobOffset"][1])
				presumedFrame:SetAttribute("PosOffsetY", data[context][actionName]["MobOffset"][2])
				presumedFrame:SetAttribute("Scalar", scalar)

				local mobBinding = Instance.new("InputBinding")
				mobBinding.UIButton = presumedFrame.Interact
				mobBinding.Name = "Mobile"

				-- // Melhoria de Design (Modern UI) // --
				presumedFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
				presumedFrame.BackgroundTransparency = 0.3

				local stroke = presumedFrame:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke", presumedFrame)
				stroke.Color = Color3.fromRGB(255, 255, 255)
				stroke.Transparency = 0.8
				stroke.Thickness = 2
				stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

				local interact = presumedFrame:FindFirstChild("Interact")
				if interact then
					interact.Font = Enum.Font.GothamBold
					interact.TextColor3 = Color3.fromRGB(255, 255, 255)
					interact.TextSize = 14
					interact.TextStrokeTransparency = 0.8
				end

				local shadow = presumedFrame:FindFirstChild("Shadow")
				if shadow then
					shadow.Visible = true
					shadow.ImageColor3 = Color3.new(0,0,0)
					shadow.ImageTransparency = 0.4
					shadow.Size = UDim2.new(1.2, 0, 1.2, 0)
					shadow.Position = UDim2.new(0.5, 0, 0.5, 2)
				end

				local gradient = Instance.new("UIGradient")
				gradient.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 150, 150))
				})
				gradient.Rotation = 45
				gradient.Parent = presumedFrame
				-- // ---------------------------- // --

				mobBinding.Parent = inputAction

				presumedFrame.Parent = mobileUI
			end

			inputAction.Parent = inputContext
		end

		inputContext.Parent = keybinds
	end


	keybinds.Parent = player
end

return KeybindInit
