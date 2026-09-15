local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui
local panel
local titleLabel
local statusLabel
local leaveButton

local STATUS_TEXT = {
	waiting = "Warte auf Spieler…",
	filling = "Fülle Lobby…",
	pending = "Arena belegt — warte…",
	starting = "Match startet!",
}

local function ensureGui()
	if gui then
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
	panel.Size = UDim2.fromOffset(300, 110)
	panel.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -16, 0, 24)
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
	statusLabel.Size = UDim2.new(1, -16, 0, 44)
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

	leaveButton = Instance.new("TextButton")
	leaveButton.Name = "LeaveButton"
	leaveButton.Size = UDim2.fromOffset(100, 28)
	leaveButton.Position = UDim2.new(1, -108, 1, -36)
	leaveButton.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
	leaveButton.Font = Enum.Font.GothamBold
	leaveButton.TextSize = 13
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

local function formatStatus(payload)
	local statusKey = payload.status or "waiting"
	local base = STATUS_TEXT[statusKey] or STATUS_TEXT.waiting
	local countLine = string.format(
		"%s — %d/%d Spieler",
		payload.modeLabel or payload.mode or "Queue",
		payload.players or 0,
		payload.maxPlayers or 1
	)

	if payload.secondsLeft and payload.secondsLeft > 0 then
		return countLine .. "\n" .. base .. " (" .. payload.secondsLeft .. "s)"
	end
	return countLine .. "\n" .. base
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	ensureGui()

	if not payload.inQueue then
		gui.Enabled = false
		return
	end

	gui.Enabled = true
	titleLabel.Text = "Queue: " .. (payload.modeLabel or payload.mode or "?")
	statusLabel.Text = formatStatus(payload)
end)
