local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local queueGui
local statusLabel
local leaveButton

local function ensureGui()
	if queueGui then
		return
	end

	queueGui = Instance.new("ScreenGui")
	queueGui.Name = "MatchmakingQueue"
	queueGui.ResetOnSpawn = false
	queueGui.Enabled = false
	queueGui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromOffset(280, 110)
	panel.Position = UDim2.new(0.5, -140, 1, -130)
	panel.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	panel.Parent = queueGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -16, 0, 22)
	title.Position = UDim2.fromOffset(8, 8)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 15
	title.TextColor3 = Color3.fromRGB(120, 180, 255)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Matchmaking"
	title.Parent = panel

	statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.Size = UDim2.new(1, -16, 0, 48)
	statusLabel.Position = UDim2.fromOffset(8, 32)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.TextSize = 13
	statusLabel.TextColor3 = Color3.new(1, 1, 1)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextYAlignment = Enum.TextYAlignment.Top
	statusLabel.TextWrapped = true
	statusLabel.Text = ""
	statusLabel.Parent = panel

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
	ensureGui()
	queueGui.Enabled = false
end

local function showQueue(payload)
	ensureGui()
	queueGui.Enabled = true

	if payload.status == "pending" then
		statusLabel.Text = string.format(
			"%s\nArena belegt — warte auf freien Slot…\nSpieler in Queue: %d/%d",
			payload.modeLabel or "Queue",
			payload.playersInQueue or 0,
			payload.maxPlayers or 0
		)
	elseif payload.status == "waiting" then
		statusLabel.Text = string.format(
			"%s\nSpieler: %d/%d (du: #%d)",
			payload.modeLabel or "Queue",
			payload.playersInQueue or 0,
			payload.minPlayers or 1,
			payload.position or 1
		)
	else
		statusLabel.Text = payload.modeLabel or "Queue"
	end
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if not payload or payload.status == "idle" or payload.status == "matched" then
		hideQueue()
		return
	end
	showQueue(payload)
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" then
		hideQueue()
	end
end)

Remotes.MatchState.OnClientEvent:Connect(function()
	hideQueue()
end)
