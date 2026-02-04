local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ANIMATIONS_FOLDER = ReplicatedStorage:WaitForChild("Animations") :: Folder 

return {
	HoldBall = ANIMATIONS_FOLDER:WaitForChild("HoldBall") :: Animation,
	KeeperAnimation = ANIMATIONS_FOLDER:WaitForChild("KeeperAnimation") :: Animation,
	LHandChargeThrow = ANIMATIONS_FOLDER:WaitForChild("LHandChargeThrow") :: Animation,
	RHandChargeThrow = ANIMATIONS_FOLDER:WaitForChild("RHandChargeThrow") :: Animation,
	LHandTackle = ANIMATIONS_FOLDER:WaitForChild("LHandTackle") :: Animation,
	RHandTackle = ANIMATIONS_FOLDER:WaitForChild("RHandTackle") :: Animation,
	SwitchHands = ANIMATIONS_FOLDER:WaitForChild("SwitchHands") :: Animation,
	LHandThrow = ANIMATIONS_FOLDER:WaitForChild("LHandThrow") :: Animation,
	RHandThrow = ANIMATIONS_FOLDER:WaitForChild("RHandThrow") :: Animation,
}