local TweenService = game:GetService("TweenService")
local Info = TweenInfo.new(.1, 
	Enum.EasingStyle.Linear, 
	Enum.EasingDirection.In)


local Teams = game:GetService("Teams")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Maid = require(ReplicatedStorage:WaitForChild("Utils"):WaitForChild("Maid"))

local LocalPlayer = Players.LocalPlayer

local SetPieceEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SetPiece")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Celebrations = Remotes:WaitForChild("Celebrations")

local Taker = ReplicatedStorage:WaitForChild("GameInfo"):WaitForChild("Taker")
local SetPiece = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SetPiece")

local Cooldown = false
local PresumedIndex = 0
local changed = false

local takerMaid = Maid.new()

local function MobileVisible(MainFrame: Frame)
	if UserInputService.TouchEnabled then
		MainFrame.Take.Visible = true
		takerMaid:GiveTask(MainFrame.Take.MouseButton1Click:Connect(function()
			SetPiece:FireServer()
		end))
	end
end

local function HandleScore(text: string, homePosession: boolean)
	local teamName = LocalPlayer.Team.Name
	PresumedIndex += 1
	local MainFrame = script.Out:Clone()
	
	MainFrame.ZIndex = PresumedIndex
	MainFrame.Action.Text = text

	if homePosession ~= nil then
		if homePosession and LocalPlayer.Team.Name:find("Home") then
			MainFrame.Action.Text ..= " press T to take"
			MobileVisible(MainFrame)
		elseif not homePosession and LocalPlayer.Team.Name:find("Away") then
			MainFrame.Action.Text ..= " press T to take"
			MobileVisible(MainFrame)
		end

		if Taker.Value ~= "" then
			MainFrame.Action.Text = text.." - "..Taker.Value
		end


		takerMaid:GiveTask(Taker:GetPropertyChangedSignal("Value"):Connect(function()
			if not MainFrame then return end
			if Taker.Value ~= "" then
				changed = true
				MainFrame.Action.Text = text.."\nTaker: "..Taker.Value
			elseif changed then
				MainFrame.Action.Text = text
			end
		end))
	end

	MainFrame.Parent = script.Parent.Parent.Scoreboard
	local FirstMove = TweenService:Create(MainFrame, Info, {Position = UDim2.new(0.5, 0,0.15, 0)})
	FirstMove:Play()
	FirstMove.Completed:Wait()
	task.wait(8)
	local FinalMove = TweenService:Create(MainFrame, Info, {Position = UDim2.new(0.5, 0, -0.3, 0)})
	FinalMove:Play()
	FinalMove.Completed:Wait()
	takerMaid:Destroy()
	MainFrame:Destroy()
	
	
	if PresumedIndex >= 999999998 then
		PresumedIndex = 0
	end
end

SetPieceEvent.OnClientEvent:Connect(HandleScore)