local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui
local panel
local titleLabel
local statusLabel
local leaveButton

local function ensureGui()
	if gui then
		return
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "MatchmakingQueue"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 16)
	panel.Size = UDim2.fromOffset(320, 120)
	panel.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -16, 0, 28)
	titleLabel.Position = UDim2.fromOffset(8, 8)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 16
	titleLabel.TextColor3 = Color3.fromRGB(120, 180, 255)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = "Warteschlange"
	titleLabel.Parent = panel

	statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.Size = UDim2.new(1, -16, 0, 48)
	statusLabel.Position = UDim2.fromOffset(8, 36)
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
	leaveButton.Size = UDim2.fromOffset(120, 28)
	leaveButton.Position = UDim2.new(1, -128, 1, -36)
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

local function statusText(payload)
	if payload.status == "pending" or payload.arenaBusy then
		return "Arena belegt — du bist als Nächster dran."
	elseif payload.status == "filling" then
		return string.format(
			"Spieler: %d / %d\nWarte auf weitere Gegner…",
			payload.count,
			payload.maxPlayers
		)
	elseif payload.status == "starting" then
		return "Match startet gleich…"
	end

	return string.format(
		"Spieler: %d / %d\nWarte auf Mitspieler…",
		payload.count,
		payload.maxPlayers
	)
end

local function showQueue(payload)
	ensureGui()
	gui.Enabled = true
	titleLabel.Text = "Warteschlange: " .. (payload.label or payload.modeId or "Match")
	statusLabel.Text = statusText(payload)
end

local function hideQueue()
	if gui then
		gui.Enabled = false
	end
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if payload.status == "idle" then
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
