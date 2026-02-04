type ShootProperties = {
	Shoot: "L Click" | "R Click" | "L/R Click",
	Power: number,
	Direction: Vector3,
}

type Shoots = "L Click" | "R Click" | "L/R Click"

local Kick = {}

local PowerAttributes = {
	["L Click"] = 50,
	["R Click"] = 25,
	["Y Axis Buffer"] = 90,
	["Default Power Buff"] = 120,
	["Driven Multiplier"] = 50,
	["Driven Power Modifier"] = 3
}

function ReleaseBall(BallInstance: MeshPart, Torso: BasePart): Vector3
	local lookVector: Vector3 = Torso.CFrame.LookVector.Unit
	local releaseBuffer: number = 6
	local decim: number = math.abs(lookVector.X) + math.abs(lookVector.Z)
	
	local xPosition: number = (lookVector.X/decim) * releaseBuffer
	local zPosition: number = (lookVector.Z/decim) * releaseBuffer
	
	return Vector3.new(BallInstance.Position.X + xPosition, BallInstance.Position.Y, BallInstance.Position.Z + zPosition)
end

function calculatePower(ShootType: Shoots, Charged: number): (number, number)
	local power, powerY
	local finalPower = (Charged / 100) * 3
	
	if ShootType ~= "L/R Click" then
		power = (PowerAttributes[ShootType] / 3) * finalPower + PowerAttributes["Default Power Buff"]
	else
		power = (finalPower/3) * PowerAttributes["Driven Power Modifier"]
	end
	
	if ShootType == "R Click" then
		powerY = 2 * finalPower + PowerAttributes["Y Axis Buffer"]
	end
		
	return power, powerY
end

function Kick.new(BallInstance: MeshPart, Character: Model, Properties: ShootProperties, ballHoldTime: number): (Vector3, Vector3)
	local releasePosition = ReleaseBall(BallInstance, Character.Torso)
	
	if ballHoldTime and (os.clock() - ballHoldTime) < 0.25 then
		Properties.Power *= 1.15
	end
	
	local power, powerY = calculatePower(Properties.Shoot, Properties.Power)
	
	
	if Properties.Shoot == "L Click" then
		local Velocity = Properties.Direction * power
		return Velocity, releasePosition
	elseif Properties.Shoot == "R Click" then
		local Velocity = Properties.Direction * Vector3.new(power, 0, power) + Vector3.new(0, powerY, 0)
		return Velocity, releasePosition
	elseif Properties.Shoot == "L/R Click" then
		local Velocity = Vector3.new(Properties.Direction.X, 0.25, Properties.Direction.Z) * 2.25 * (PowerAttributes["Driven Multiplier"] + power)
		return Velocity, releasePosition, true	
	end
end

function Kick:HandleDriven(Ball)
	local BodyForce = Instance.new("BodyForce")
	BodyForce.Force = Vector3.new(0, (Ball:GetMass() * 196.2) * 0.75, 0)
	BodyForce.Parent = Ball
	task.wait(0.5)
	local cancelDriven
	cancelDriven = Ball.Touched:Connect(function(hit)
		if hit.Name == "Field" then
			if BodyForce then
				BodyForce:Destroy()
				cancelDriven:Disconnect()
			end
		end
	end)
end

return Kick

