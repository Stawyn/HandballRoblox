local TweenService = game:GetService("TweenService")
local Info = TweenInfo.new(.1, 
	Enum.EasingStyle.Linear, 
	Enum.EasingDirection.In)
local Teams = game:GetService("Teams")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ScorerEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Scored")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Celebrations = Remotes:WaitForChild("Celebrations")

local Cooldown = false
local PresumedIndex = 0

-- UI START POSITION > {0.5, 0},{-0.15, 0}
-- UI END POSITION > {0.5, 0},{0.15, 0}
local function HandleScore(Scorer,Assister, OG)
	
	PresumedIndex += 1
	local MainFrame = script.Scorer:Clone()
	MainFrame.ZIndex = PresumedIndex
	MainFrame.Parent = script.Parent.Parent.Scoreboard
	
	if OG == true then
		MainFrame.Action.Text = "OWN GOAL!"
		Celebrations:FireServer(Scorer, OG)
	else
		MainFrame.Action.Text = "GOAL!"
		Celebrations:FireServer(Scorer, OG)
	end
	
	
	if not Assister then		
		local thumbnailType = Enum.ThumbnailType.HeadShot
		local thumbnailSize = Enum.ThumbnailSize.Size420x420
		
		local content, isReady = Players:GetUserThumbnailAsync(Scorer.UserId, thumbnailType, thumbnailSize)
		
		MainFrame.Folder.Scorer.Image = content
		MainFrame.Folder.ScorerText.Text = "[SCORER] "..Scorer.Name
		MainFrame.Folder.Scorer.Visible = true
		MainFrame.Folder.Assister.Visible = false
		MainFrame.Folder.AssisterText.Visible = false
		
	else
		local thumbnailType = Enum.ThumbnailType.HeadShot
		local thumbnailSize = Enum.ThumbnailSize.Size420x420

		local content, isReady = Players:GetUserThumbnailAsync(Scorer.UserId, thumbnailType, thumbnailSize)
		local content2, isReady2 = Players:GetUserThumbnailAsync(Assister.UserId, thumbnailType, thumbnailSize)
		
		MainFrame.Folder.Scorer.Image = content
		MainFrame.Folder.Assister.Image = content2
		MainFrame.Folder.ScorerText.Text = "[SCORER] "..Scorer.Name
		MainFrame.Folder.AssisterText.Text = "[ASSIST] "..Assister.Name
		MainFrame.Folder.Scorer.Visible = true
		MainFrame.Folder.Assister.Visible = true
		MainFrame.Folder.AssisterText.Visible = true

	end
		
	local FirstMove = TweenService:Create(MainFrame, Info, {Position = UDim2.new(0.5, 0,0.15, 0)})
	FirstMove:Play()
	FirstMove.Completed:Wait()
	task.wait(2)
	MainFrame.Action.Text = ""
	local SecondMove = TweenService:Create(MainFrame.Frame2, Info, {Size = UDim2.new(1, 0, 0, 0)})
	SecondMove:Play()
	SecondMove.Completed:Wait()
	task.wait(2)
	local FinalMove = TweenService:Create(MainFrame, Info, {Position = UDim2.new(0.5, 0, -0.3, 0)})
	FinalMove:Play()
	FinalMove.Completed:Wait()
	MainFrame.Frame2.Size = UDim2.new(1, 0, 1, 0)

	if PresumedIndex >= 999999998 then
		PresumedIndex = 0
	end
end

ScorerEvent.OnClientEvent:Connect(HandleScore)