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
	panel.Size = UDim2.fromOffset(260, 180)
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
	startBtn.Text = "Queue beitreten"
	startBtn.Parent = panel

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = startBtn

	local lb = Instance.new("TextLabel")
	lb.Name = "LeaderboardLabel"
	lb.Size = UDim2.new(1, -16, 0, 40)
	lb.Position = UDim2.fromOffset(8, 132)
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

if not playerGui:FindFirstChild("Queue") then
	local queueGui = Instance.new("ScreenGui")
	queueGui.Name = "Queue"
	queueGui.ResetOnSpawn = false
	queueGui.Enabled = false
	queueGui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromOffset(280, 200)
	panel.Position = UDim2.new(0.5, -140, 0, 12)
	panel.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	panel.Parent = queueGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	local modeLabel = Instance.new("TextLabel")
	modeLabel.Name = "ModeLabel"
	modeLabel.Size = UDim2.new(1, -16, 0, 24)
	modeLabel.Position = UDim2.fromOffset(8, 8)
	modeLabel.BackgroundTransparency = 1
	modeLabel.Font = Enum.Font.GothamBold
	modeLabel.TextSize = 16
	modeLabel.TextColor3 = Color3.fromRGB(120, 180, 255)
	modeLabel.TextXAlignment = Enum.TextXAlignment.Left
	modeLabel.Text = "Warteschlange"
	modeLabel.Parent = panel

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, -16, 0, 36)
	statusLabel.Position = UDim2.fromOffset(8, 34)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.TextSize = 13
	statusLabel.TextColor3 = Color3.new(1, 1, 1)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextYAlignment = Enum.TextYAlignment.Top
	statusLabel.TextWrapped = true
	statusLabel.Text = ""
	statusLabel.Parent = panel

	local positionLabel = Instance.new("TextLabel")
	positionLabel.Name = "PositionLabel"
	positionLabel.Size = UDim2.new(1, -16, 0, 18)
	positionLabel.Position = UDim2.fromOffset(8, 72)
	positionLabel.BackgroundTransparency = 1
	positionLabel.Font = Enum.Font.Gotham
	positionLabel.TextSize = 12
	positionLabel.TextColor3 = Color3.fromRGB(180, 190, 210)
	positionLabel.TextXAlignment = Enum.TextXAlignment.Left
	positionLabel.Text = ""
	positionLabel.Parent = panel

	local playersLabel = Instance.new("TextLabel")
	playersLabel.Name = "PlayersLabel"
	playersLabel.Size = UDim2.new(1, -16, 0, 72)
	playersLabel.Position = UDim2.fromOffset(8, 92)
	playersLabel.BackgroundTransparency = 1
	playersLabel.Font = Enum.Font.Gotham
	playersLabel.TextSize = 12
	playersLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
	playersLabel.TextXAlignment = Enum.TextXAlignment.Left
	playersLabel.TextYAlignment = Enum.TextYAlignment.Top
	playersLabel.Text = ""
	playersLabel.Parent = panel

	local leaveBtn = Instance.new("TextButton")
	leaveBtn.Name = "LeaveButton"
	leaveBtn.Size = UDim2.fromOffset(120, 28)
	leaveBtn.Position = UDim2.new(1, -128, 1, -36)
	leaveBtn.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
	leaveBtn.Font = Enum.Font.GothamBold
	leaveBtn.TextSize = 13
	leaveBtn.TextColor3 = Color3.new(1, 1, 1)
	leaveBtn.Text = "Verlassen"
	leaveBtn.Parent = panel

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = leaveBtn
end
