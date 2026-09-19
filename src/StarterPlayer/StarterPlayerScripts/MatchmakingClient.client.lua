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
	queueGui.DisplayOrder = 12
	queueGui.Enabled = false
	queueGui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 72)
	panel.Size = UDim2.fromOffset(300, 110)
	panel.BackgroundColor3 = Color3.fromRGB(22, 26, 36)
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Parent = queueGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(90, 140, 255)
	stroke.Thickness = 1.5
	stroke.Transparency = 0.35
	stroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 8)
	title.Size = UDim2.new(1, -24, 0, 22)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextColor3 = Color3.fromRGB(180, 210, 255)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Warteschlange"
	title.Parent = panel

	statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.BackgroundTransparency = 1
	statusLabel.Position = UDim2.fromOffset(12, 32)
	statusLabel.Size = UDim2.new(1, -24, 0, 44)
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.TextSize = 14
	statusLabel.TextColor3 = Color3.fromRGB(220, 225, 235)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextYAlignment = Enum.TextYAlignment.Top
	statusLabel.TextWrapped = true
	statusLabel.Text = ""
	statusLabel.Parent = panel

	leaveButton = Instance.new("TextButton")
	leaveButton.Name = "LeaveButton"
	leaveButton.AnchorPoint = Vector2.new(1, 1)
	leaveButton.Position = UDim2.new(1, -12, 1, -10)
	leaveButton.Size = UDim2.fromOffset(110, 28)
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

local function hideQueue()
	ensureGui()
	queueGui.Enabled = false
end

local function showQueue(payload)
	ensureGui()

	if payload.matchStarting then
		statusLabel.Text = string.format("Match startet — %s", payload.modeLabel or "")
		queueGui.Enabled = true
		leaveButton.Visible = false
		return
	end

	if not payload.inQueue then
		hideQueue()
		return
	end

	local lines = {
		string.format("Modus: %s", payload.modeLabel or payload.modeId or "?"),
		string.format("Spieler: %d / %d", payload.queued or 0, payload.maxPlayers or 0),
	}

	if payload.pending then
		table.insert(lines, "Arena belegt — warte...")
	elseif payload.fillRemaining and payload.fillRemaining > 0 then
		table.insert(lines, string.format("Start in ~%ds", payload.fillRemaining))
	else
		table.insert(lines, "Suche Gegner...")
	end

	statusLabel.Text = table.concat(lines, "\n")
	leaveButton.Visible = true
	queueGui.Enabled = true
end

Remotes.QueueUpdate.OnClientEvent:Connect(showQueue)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" then
		hideQueue()
	end
end)
