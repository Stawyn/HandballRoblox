local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorkSpace = game:GetService("Workspace")

local Character  = {}
local bodyParts = {"Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "Torso", "HumanoidRootPart"}
local leagueTeams = {"Denos", "CPM", "Resers", "Gelerme", "Coca"}
local cardSystem = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Systems"):WaitForChild("CardSystem"))
local awayName = WorkSpace.Core.Data.AwayName
local homeName = WorkSpace.Core.Data.HomeName
local kits = script.Kits

function Character:Init(player: Player)

	local function onCharacterAdded(character: Model)
		if not player:HasAppearanceLoaded() then
			player.CharacterAppearanceLoaded:Wait()
		end

		for _, v in character:GetChildren() do
			if v:IsA("Accessory") then
				v.Handle.CanTouch = false
			elseif (v:IsA("Shirt") or v:IsA("Pants")) and player.Team and kits:FindFirstChild(player.Team.Name) then
				if v:IsA("Shirt") then
					v:Destroy()
				elseif v:IsA("Pants") then
					v:Destroy()
				end
			end
		end

		cardSystem:OnCharacterAdded(player)

		for _, bodyPart in bodyParts do
			local bodyPart = character:WaitForChild(bodyPart) :: BasePart
			if player.Team and player.Team.Name:find("Goalkeeper") then
				bodyPart.CollisionGroup = "Goalkeeper"
			else
				bodyPart.CollisionGroup = "Player"
			end
		end

		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		task.wait()
		local currentDescription = humanoid:GetAppliedDescription()

		currentDescription.Head = 0	
		currentDescription.Torso = 0
		currentDescription.LeftArm = 0
		currentDescription.RightArm  = 0
		currentDescription.LeftLeg = 0
		currentDescription.RightLeg = 0
		humanoid:ApplyDescriptionAsync(currentDescription) 

		local function Kits(Team)

			if kits:FindFirstChild(Team) then
				local newShirt = kits:FindFirstChild(Team):FindFirstChild("Shirt"):Clone()
				local newPants = kits:FindFirstChild(Team):FindFirstChild("Pants"):Clone()

				newShirt.Parent = character
				newPants.Parent = character
			end

		end

		if player.Team then
			if not table.find(leagueTeams, homeName.Value) and player.Team.Name ~= "Officials" and not table.find(leagueTeams, awayName.Value) then
				Kits(player.Team.Name)
			elseif table.find(leagueTeams, awayName.Value) and player.Team.Name ~= "Officials" and player.Team.Name:find("Away") then
				Kits(awayName.Value.."Away")
			elseif table.find(leagueTeams, homeName.Value) and player.Team.Name ~= "Officials" and player.Team.Name:find("Home") then
				Kits(homeName.Value.."Home")
			elseif player.Team.Name == "Officials" then
				Kits(player.Team.Name)
			end
		end
	end



	if player.Character then
		coroutine.wrap(onCharacterAdded)(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)
	player:GetPropertyChangedSignal("Team"):Connect(function()
		if player.Character then
			coroutine.wrap(onCharacterAdded)(player.Character)
		end
	end)
end

return Character
