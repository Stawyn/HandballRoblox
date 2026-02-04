local SortStandsByFieldProximity = require(script.SortStandsByFieldProximity)
local ShuffleTable = require(script.ShuffleTable)
local CrowdAssets = require(script.CrowdAssets)
local ResetCrowdMapping = require(script.ResetCrowdMapping)
local CrowdModule = {}

local INITIALIZED = false
local BASE_PERCENTAGE = 0
local FIELD_POSITION = Vector3.new(0,0,0)

function CrowdModule:ResetCrowdTexture()
	for index: number, stand: BasePart in pairs(workspace:GetDescendants()) do
		if not stand:IsA("BasePart") then continue end
		if not stand.Name:find("Seat") then continue end
		if not stand:FindFirstChild("SeatChange") then continue end

		for i, v in pairs(stand:GetChildren()) do
			if v.Name ~= "Crowd" then continue end
			local CrowdAssetsTable = CrowdAssets[9]
			local CurrentTexture = v.Texture
			v.Texture = CrowdAssetsTable[math.random(1, #CrowdAssetsTable)]
		end
	end
end

function CrowdModule:GetCapacityAndStands(): {["Capacity"]: number, ["Stands"]: {[number]: BasePart}}
	local Capacity = 0
	local Stands = {}

	for index: number, stand: BasePart in pairs(workspace:GetDescendants()) do
		if not stand:IsA("BasePart") then continue end
		if not stand.Name:find("Seat") then continue end
		if not stand:FindFirstChild("SeatChange") then continue end

		local XSize = stand.Size.X
		local ZSide = stand.Size.Z
		local FullStandSize = XSize > ZSide and XSize or ZSide
		local SeatSize = stand.SeatChange.StudsPerTileU

		local StandQuantity = FullStandSize / SeatSize
		Capacity += StandQuantity
		table.insert(Stands, stand)
	end

	return {["Capacity"] = math.ceil(Capacity), ["Stands"] = Stands}
end

function CrowdModule:GetPartialCapacity(CurrentStands: {BasePart}): {["Capacity"]: number}
	local Capacity = 0
	
	for index, stand in pairs(CurrentStands) do
		local XSize = stand.Size.X
		local ZSide = stand.Size.Z
		local FullStandSize = XSize > ZSide and XSize or ZSide
		local SeatSize = stand.SeatChange.StudsPerTileU

		local StandQuantity = FullStandSize / SeatSize
		
		local PresumedTexture
		for _, nestedTable in pairs(CrowdAssets) do
			if not table.find(nestedTable, stand.Crowd.Texture) then continue end
			PresumedTexture = table.find(nestedTable, stand.Crowd.Texture)
		end
		
		Capacity += (StandQuantity / PresumedTexture)
	end
	
	return math.ceil(Capacity)
end

function CrowdModule:PopulateStadium()
	ResetCrowdMapping()
	local CapacityAndStands = CrowdModule:GetCapacityAndStands()
	local SortedStandsByProximity = SortStandsByFieldProximity(CapacityAndStands["Stands"], FIELD_POSITION)

	local PopulateStandsTo = #CapacityAndStands["Stands"] * (BASE_PERCENTAGE / 100)
	local NewStadiumCapacity = math.ceil(CapacityAndStands["Capacity"]) * (BASE_PERCENTAGE / 100)
	local MinShufflePercentage = 100 * (math.random(40, 80) / 100)
	local ActualPercentage = #CapacityAndStands["Stands"] * (MinShufflePercentage / 100)

	if not INITIALIZED then
		INITIALIZED = true
		local ToNotShuffle = {}
		for index, stand in pairs(SortedStandsByProximity) do
			if index >= ActualPercentage then
				table.insert(ToNotShuffle, stand)
				SortedStandsByProximity[index] = nil
			end
		end
		ShuffleTable(SortedStandsByProximity)
		for _, stand in pairs(ToNotShuffle) do
			table.insert(SortedStandsByProximity, stand)
		end
	end

	for index = #SortedStandsByProximity, 1, -1 do
		local stand = SortedStandsByProximity[index]

		for _, v in pairs(stand:GetChildren()) do
			if v.Name == "Crowd" then
				v.Transparency = index > PopulateStandsTo and 1 or 0
			end
		end
		
		if index > PopulateStandsTo then
			table.remove(SortedStandsByProximity, index)
		end
	end

	local Difference = math.ceil(CapacityAndStands["Capacity"] - NewStadiumCapacity)
	
	for _, stand in pairs(SortedStandsByProximity) do
		if Difference < 1 then
			break
		end

		stand.Crowd.Transparency = 0
		local CrowdSize = stand.Crowd.StudsPerTileU
		local OnePerson = CrowdSize / 9

		local AmmountToDecrease = math.min(math.ceil(math.random(OnePerson, CrowdSize) / 4), 9)
		AmmountToDecrease = math.max(AmmountToDecrease, 1)
		local CrowdAssetsTable = CrowdAssets[AmmountToDecrease]

		for i, v in pairs(stand:GetChildren()) do
			if v.Name ~= "Crowd" then continue end
			local CurrentCrowdTexture = v.Texture
			local PresumedTexture
			for index, nestedTable in pairs(CrowdAssets) do
				if not table.find(nestedTable, CurrentCrowdTexture) then continue end
				PresumedTexture = table.find(nestedTable, CurrentCrowdTexture)
			end
			local TextureIndex = PresumedTexture or math.random(1, #CrowdAssetsTable)
			v.Texture = CrowdAssetsTable[TextureIndex]
		end

		Difference -= AmmountToDecrease
	end
	
end

function CrowdModule:SetCrowdBaseAttendance(givenAttendance: number)
	assert(typeof(givenAttendance) == "number", "Expected number, got " .. typeof(givenAttendance))
	assert(givenAttendance >= 0, "Attendance count must be a non-negative number")
	local MaximumCapacity = CrowdModule:GetCapacityAndStands()["Capacity"]
	local AttendancePercentage = math.ceil((givenAttendance/MaximumCapacity) * 100)
	
	BASE_PERCENTAGE = AttendancePercentage
end

function CrowdModule:SetFieldPosition(position: Vector3)
	assert(typeof(position) == "Vector3", "Expected Vector3, got " .. typeof(position))
	FIELD_POSITION = position
end

function CrowdModule:SetBasePercentage(percentage: number)
	assert(typeof(percentage) == "number", "Expected number, got " .. typeof(percentage))
	assert(percentage <= 100 and percentage >= 0, "Percentage must be between 0 and 100")
	BASE_PERCENTAGE = percentage
end

function CrowdModule:SetBasePercentageAndPopulate(percentage: number)
	CrowdModule:SetBasePercentage(percentage)
	CrowdModule:PopulateStadium()
end

function CrowdModule:GetPercentage(): number
	return BASE_PERCENTAGE
end

return CrowdModule

