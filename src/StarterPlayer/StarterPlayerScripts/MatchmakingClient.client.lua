local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui
local panel
local statusLabel
local detailLabel
local leaveButton

local function ensureGui()
	local playerGui = player:WaitForChild("PlayerGui")
	gui = playerGui:FindFirstChild("MatchmakingQueue")
	if gui then
		panel = gui:FindFirstChild("Panel")
		statusLabel = panel:FindFirstChild("StatusLabel")
		detailLabel = panel:FindFirstChild("DetailLabel")
		leaveButton = panel:FindFirstChild("LeaveButton")
		return
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "MatchmakingQueue"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 5
	gui.Parent = playerGui

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 12)
	panel.Size = UDim2.fromOffset(320, 110)
	panel.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, -16, 0, 24)
	statusLabel.Position = UDim2.fromOffset(8, 8)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.TextSize = 15
	statusLabel.TextColor3 = Color3.fromRGB(120, 180, 255)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Text = "Warteschlange"
	statusLabel.Parent = panel

	detailLabel = Instance.new("TextLabel")
	detailLabel.Name = "DetailLabel"
	detailLabel.Size = UDim2.new(1, -16, 0, 44)
	detailLabel.Position = UDim2.fromOffset(8, 34)
	detailLabel.BackgroundTransparency = 1
	detailLabel.Font = Enum.Font.GothamMedium
	detailLabel.TextSize = 13
	detailLabel.TextColor3 = Color3.new(1, 1, 1)
	detailLabel.TextXAlignment = Enum.TextXAlignment.Left
	detailLabel.TextYAlignment = Enum.TextYAlignment.Top
	detailLabel.TextWrapped = true
	detailLabel.Text = ""
	detailLabel.Parent = panel

	leaveButton = Instance.new("TextButton")
	leaveButton.Name = "LeaveButton"
	leaveButton.Size = UDim2.fromOffset(100, 26)
	leaveButton.Position = UDim2.new(1, -108, 1, -34)
	leaveButton.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
	leaveButton.Font = Enum.Font.GothamBold
	leaveButton.TextSize = 12
	leaveButton.TextColor3 = Color3.new(1, 1, 1)
	leaveButton.Text = "Verlassen"
	leaveButton.Parent = panel

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = leaveButton

	leaveButton.MouseButton1Click:Connect(function()
		Remotes.QueueLeave:FireServer()
	end)
end

local function hideQueue()
	if gui then
		gui.Enabled = false
	end
end

local function showQueue(payload)
	ensureGui()

	if payload.status == "idle" or payload.status == "matched" then
		hideQueue()
		return
	end

	local modeLabel = payload.modeLabel or payload.modeId or "Arena"
	local queueSize = payload.queueSize or 0
	local minPlayers = payload.minPlayers or 1
	local maxPlayers = payload.maxPlayers or minPlayers

	if payload.status == "pending" or payload.arenaBusy then
		statusLabel.Text = string.format("⏳ %s — Arena belegt", modeLabel)
		detailLabel.Text = "Match startet, sobald die Arena frei ist."
	elseif payload.status == "filling" then
		local secondsLeft = payload.fillSecondsLeft or 0
		statusLabel.Text = string.format("🔄 %s — Start in %ds", modeLabel, secondsLeft)
		detailLabel.Text = string.format(
			"%d/%d Spieler in Warteschlange (max. %d)",
			queueSize,
			minPlayers,
			maxPlayers
		)
	else
		statusLabel.Text = string.format("🔍 %s — Suche Gegner", modeLabel)
		detailLabel.Text = string.format(
			"%d/%d Spieler (max. %d)",
			queueSize,
			minPlayers,
			maxPlayers
		)
	end

	gui.Enabled = true
end

Remotes.QueueUpdate.OnClientEvent:Connect(showQueue)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" then
		hideQueue()
	end
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	hideQueue()
end)

ensureGui()
