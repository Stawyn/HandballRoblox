local SharedAttributes = {}
local StarterPlayer = game:GetService("StarterPlayer")

local walkSpeed = StarterPlayer.CharacterWalkSpeed

function SharedAttributes:GetWalkSpeed()
	return walkSpeed 
end

function SharedAttributes:GetSprintSpeed()
	return walkSpeed + 7
end

function SharedAttributes:GetGoalkeeperSpeed()
	return 10
end

function SharedAttributes:GetGoalkeeperFocusedSpeed()
	return 4
end

function SharedAttributes:GetKDrag()
	return 0.7
end

function SharedAttributes:MaxPing()
	return 350
end

return SharedAttributes