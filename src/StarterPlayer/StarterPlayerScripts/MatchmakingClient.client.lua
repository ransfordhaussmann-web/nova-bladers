local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui
local panel
local titleLabel
local statusLabel
local countLabel
local leaveButton

local STATUS_TEXT = {
	waiting = "Warte auf Spieler…",
	filling = "Fülle Lobby…",
	ready = "Match startet…",
	pending = "Arena belegt — wartet…",
}

local function ensureGui()
	if gui then
		return
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "MatchmakingQueue"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = playerGui

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 12)
	panel.Size = UDim2.fromOffset(300, 96)
	panel.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -16, 0, 22)
	titleLabel.Position = UDim2.fromOffset(8, 8)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 15
	titleLabel.TextColor3 = Color3.fromRGB(120, 180, 255)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = "Matchmaking"
	titleLabel.Parent = panel

	statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, -16, 0, 18)
	statusLabel.Position = UDim2.fromOffset(8, 32)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.TextSize = 13
	statusLabel.TextColor3 = Color3.new(1, 1, 1)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Text = ""
	statusLabel.Parent = panel

	countLabel = Instance.new("TextLabel")
	countLabel.Name = "CountLabel"
	countLabel.Size = UDim2.new(1, -120, 0, 18)
	countLabel.Position = UDim2.fromOffset(8, 54)
	countLabel.BackgroundTransparency = 1
	countLabel.Font = Enum.Font.Gotham
	countLabel.TextSize = 12
	countLabel.TextColor3 = Color3.fromRGB(180, 190, 210)
	countLabel.TextXAlignment = Enum.TextXAlignment.Left
	countLabel.Text = ""
	countLabel.Parent = panel

	leaveButton = Instance.new("TextButton")
	leaveButton.Name = "LeaveButton"
	leaveButton.Size = UDim2.fromOffset(96, 28)
	leaveButton.Position = UDim2.new(1, -104, 1, -36)
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
		gui.Enabled = false
	end)
end

local function showQueue(payload)
	ensureGui()

	local modeLabel = payload.label or payload.modeId or "Queue"
	titleLabel.Text = "Queue: " .. modeLabel
	statusLabel.Text = STATUS_TEXT[payload.status] or "In Queue…"
	countLabel.Text = string.format("%d / %d Spieler", payload.count or 0, payload.max or 0)
	gui.Enabled = true
end

local function hideQueue()
	if gui then
		gui.Enabled = false
	end
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	showQueue(payload)
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		hideQueue()
	elseif state.phase == "queue" then
		ensureGui()
		gui.Enabled = true
	elseif state.phase == "arena" then
		hideQueue()
	end
end)

Remotes.MatchState.OnClientEvent:Connect(function()
	hideQueue()
end)
