--[[
    ================================================================================
    MÓDULO: Drag
    ================================================================================
    Descrição: Sistema de arrastar a janela da loja (apenas PC)
    Autor: Sistema ABH
    ================================================================================
]]

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

-- Detectar se é mobile
local IS_MOBILE = UserInputService.TouchEnabled 
	and not UserInputService.KeyboardEnabled 
	and not GuiService:IsTenFootInterface()

-- No mobile, não permitir drag (janela fica centralizada)
if IS_MOBILE then
	return
end

local gui = script.Parent

local dragging = false
local dragInput = nil
local dragStart = nil
local startPos = nil

local function update(input)
	local delta = input.Position - dragStart
	gui.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

gui.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPos = gui.Position

		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)

gui.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		dragInput = input
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input == dragInput and dragging then
		update(input)
	end
end)