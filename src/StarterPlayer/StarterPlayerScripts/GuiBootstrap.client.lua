local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

if not playerGui:FindFirstChild("Lobby") then
	local gui = Instance.new("ScreenGui")
	gui.Name = "Lobby"
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromOffset(260, 210)
	panel.Position = UDim2.fromOffset(12, 12)
	panel.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	local stats = Instance.new("TextLabel")
	stats.Name = "StatsLabel"
	stats.Size = UDim2.new(1, -16, 0, 60)
	stats.Position = UDim2.fromOffset(8, 8)
	stats.BackgroundTransparency = 1
	stats.Font = Enum.Font.GothamMedium
	stats.TextSize = 14
	stats.TextColor3 = Color3.new(1, 1, 1)
	stats.TextXAlignment = Enum.TextXAlignment.Left
	stats.TextYAlignment = Enum.TextYAlignment.Top
	stats.Text = "Wins: 0\nLosses: 0\nRank: 0"
	stats.Parent = panel

	local mode = Instance.new("TextLabel")
	mode.Name = "ModeLabel"
	mode.Size = UDim2.new(1, -16, 0, 20)
	mode.Position = UDim2.fromOffset(8, 72)
	mode.BackgroundTransparency = 1
	mode.Font = Enum.Font.GothamBold
	mode.TextSize = 13
	mode.TextColor3 = Color3.fromRGB(120, 180, 255)
	mode.TextXAlignment = Enum.TextXAlignment.Left
	mode.Text = "Modus: Training"
	mode.Parent = panel

	local startBtn = Instance.new("TextButton")
	startBtn.Name = "StartButton"
	startBtn.Size = UDim2.fromOffset(120, 28)
	startBtn.Position = UDim2.fromOffset(8, 100)
	startBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 255)
	startBtn.Font = Enum.Font.GothamBold
	startBtn.TextSize = 13
	startBtn.TextColor3 = Color3.new(1, 1, 1)
	startBtn.Text = "Schnellmatch"
	startBtn.Parent = panel

	local queueLabel = Instance.new("TextLabel")
	queueLabel.Name = "QueueLabel"
	queueLabel.Size = UDim2.new(1, -16, 0, 32)
	queueLabel.Position = UDim2.fromOffset(8, 96)
	queueLabel.BackgroundTransparency = 1
	queueLabel.Font = Enum.Font.GothamMedium
	queueLabel.TextSize = 12
	queueLabel.TextColor3 = Color3.fromRGB(180, 210, 255)
	queueLabel.TextXAlignment = Enum.TextXAlignment.Left
	queueLabel.TextYAlignment = Enum.TextYAlignment.Top
	queueLabel.Text = ""
	queueLabel.Visible = false
	queueLabel.Parent = panel

	local cancelBtn = Instance.new("TextButton")
	cancelBtn.Name = "CancelQueueButton"
	cancelBtn.Size = UDim2.fromOffset(120, 28)
	cancelBtn.Position = UDim2.fromOffset(136, 100)
	cancelBtn.BackgroundColor3 = Color3.fromRGB(90, 70, 80)
	cancelBtn.Font = Enum.Font.GothamBold
	cancelBtn.TextSize = 13
	cancelBtn.TextColor3 = Color3.new(1, 1, 1)
	cancelBtn.Text = "Abbrechen"
	cancelBtn.Visible = false
	cancelBtn.Parent = panel

	local cancelCorner = Instance.new("UICorner")
	cancelCorner.CornerRadius = UDim.new(0, 6)
	cancelCorner.Parent = cancelBtn

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = startBtn

	local lb = Instance.new("TextLabel")
	lb.Name = "LeaderboardLabel"
	lb.Size = UDim2.new(1, -16, 0, 40)
	lb.Position = UDim2.fromOffset(8, 162)
	lb.BackgroundTransparency = 1
	lb.Font = Enum.Font.Gotham
	lb.TextSize = 11
	lb.TextColor3 = Color3.fromRGB(180, 190, 210)
	lb.TextXAlignment = Enum.TextXAlignment.Left
	lb.TextYAlignment = Enum.TextYAlignment.Top
	lb.Text = "🏆 Top Spieler:"
	lb.Parent = panel
end

local hud = playerGui:FindFirstChild("BattleHUD")
if not hud then
	hud = Instance.new("ScreenGui")
	hud.Name = "BattleHUD"
	hud.ResetOnSpawn = false
	hud.Enabled = false
	hud.Parent = playerGui

	local statsFrame = Instance.new("Frame")
	statsFrame.Name = "StatsFrame"
	statsFrame.Size = UDim2.fromOffset(280, 120)
	statsFrame.Position = UDim2.new(1, -292, 0, 12)
	statsFrame.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	statsFrame.BackgroundTransparency = 0.2
	statsFrame.BorderSizePixel = 0
	statsFrame.Parent = hud

	local hudCorner = Instance.new("UICorner")
	hudCorner.CornerRadius = UDim.new(0, 10)
	hudCorner.Parent = statsFrame

	local statsLabel = Instance.new("TextLabel")
	statsLabel.Name = "StatsLabel"
	statsLabel.Size = UDim2.new(1, -12, 1, -12)
	statsLabel.Position = UDim2.fromOffset(6, 6)
	statsLabel.BackgroundTransparency = 1
	statsLabel.Font = Enum.Font.GothamMedium
	statsLabel.TextSize = 13
	statsLabel.TextColor3 = Color3.new(1, 1, 1)
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsLabel.TextYAlignment = Enum.TextYAlignment.Top
	statsLabel.Text = "Kampf"
	statsLabel.Parent = statsFrame

	local countdown = Instance.new("TextLabel")
	countdown.Name = "Countdown"
	countdown.Size = UDim2.fromScale(1, 1)
	countdown.BackgroundTransparency = 1
	countdown.Font = Enum.Font.GothamBlack
	countdown.TextSize = 72
	countdown.TextColor3 = Color3.new(1, 1, 1)
	countdown.TextStrokeTransparency = 0.5
	countdown.Text = ""
	countdown.Parent = hud
end

local mobile = playerGui:FindFirstChild("MobileControls")
if not mobile then
	mobile = Instance.new("ScreenGui")
	mobile.Name = "MobileControls"
	mobile.ResetOnSpawn = false
	mobile.Enabled = false
	mobile.Parent = playerGui
end
