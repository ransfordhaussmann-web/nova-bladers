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
	panel.Size = UDim2.fromOffset(280, 280)
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
	startBtn.Text = "Schnell-Match"
	startBtn.Parent = panel

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = startBtn

	local queueFrame = Instance.new("Frame")
	queueFrame.Name = "QueueFrame"
	queueFrame.Size = UDim2.new(1, -16, 0, 72)
	queueFrame.Position = UDim2.fromOffset(8, 132)
	queueFrame.BackgroundTransparency = 1
	queueFrame.Parent = panel

	local queueLayout = Instance.new("UIListLayout")
	queueLayout.FillDirection = Enum.FillDirection.Horizontal
	queueLayout.Padding = UDim.new(0, 4)
	queueLayout.Parent = queueFrame

	for _, spec in {
		{ id = "training", label = "Train", color = Color3.fromRGB(100, 180, 255) },
		{ id = "pvp", label = "1v1", color = Color3.fromRGB(255, 140, 80) },
		{ id = "ffa", label = "FFA", color = Color3.fromRGB(180, 100, 255) },
	} do
		local qBtn = Instance.new("TextButton")
		qBtn.Name = "QueueBtn_" .. spec.id
		qBtn.Size = UDim2.fromOffset(80, 28)
		qBtn.BackgroundColor3 = spec.color
		qBtn.Font = Enum.Font.GothamBold
		qBtn.TextSize = 12
		qBtn.TextColor3 = Color3.new(1, 1, 1)
		qBtn.Text = spec.label
		qBtn.Parent = queueFrame

		local qCorner = Instance.new("UICorner")
		qCorner.CornerRadius = UDim.new(0, 6)
		qCorner.Parent = qBtn
	end

	local queueStatus = Instance.new("TextLabel")
	queueStatus.Name = "QueueStatusLabel"
	queueStatus.Size = UDim2.new(1, -16, 0, 36)
	queueStatus.Position = UDim2.fromOffset(8, 206)
	queueStatus.BackgroundTransparency = 1
	queueStatus.Font = Enum.Font.GothamMedium
	queueStatus.TextSize = 12
	queueStatus.TextColor3 = Color3.fromRGB(160, 220, 160)
	queueStatus.TextXAlignment = Enum.TextXAlignment.Left
	queueStatus.TextYAlignment = Enum.TextYAlignment.Top
	queueStatus.Text = ""
	queueStatus.Parent = panel

	local leaveBtn = Instance.new("TextButton")
	leaveBtn.Name = "LeaveQueueButton"
	leaveBtn.Size = UDim2.fromOffset(120, 24)
	leaveBtn.Position = UDim2.fromOffset(8, 244)
	leaveBtn.BackgroundColor3 = Color3.fromRGB(120, 60, 60)
	leaveBtn.Font = Enum.Font.GothamBold
	leaveBtn.TextSize = 11
	leaveBtn.TextColor3 = Color3.new(1, 1, 1)
	leaveBtn.Text = "Warteschlange verlassen"
	leaveBtn.Visible = false
	leaveBtn.Parent = panel

	local leaveCorner = Instance.new("UICorner")
	leaveCorner.CornerRadius = UDim.new(0, 6)
	leaveCorner.Parent = leaveBtn

	local lb = Instance.new("TextLabel")
	lb.Name = "LeaderboardLabel"
	lb.Size = UDim2.new(1, -16, 0, 0)
	lb.Position = UDim2.fromOffset(8, 272)
	lb.BackgroundTransparency = 1
	lb.Font = Enum.Font.Gotham
	lb.TextSize = 11
	lb.TextColor3 = Color3.fromRGB(180, 190, 210)
	lb.TextXAlignment = Enum.TextXAlignment.Left
	lb.TextYAlignment = Enum.TextYAlignment.Top
	lb.Text = "🏆 Top Spieler:"
	lb.Visible = false
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
