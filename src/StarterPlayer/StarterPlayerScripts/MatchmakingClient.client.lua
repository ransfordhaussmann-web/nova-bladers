local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local function getOrCreateQueueGui()
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = playerGui:FindFirstChild("MatchmakingQueue")
	if gui then
		return gui
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "MatchmakingQueue"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 5
	gui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 72)
	panel.Size = UDim2.fromOffset(320, 118)
	panel.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "TitleLabel"
	title.Size = UDim2.new(1, -16, 0, 24)
	title.Position = UDim2.fromOffset(8, 8)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 15
	title.TextColor3 = Color3.fromRGB(120, 180, 255)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Warteschlange"
	title.Parent = panel

	local status = Instance.new("TextLabel")
	status.Name = "StatusLabel"
	status.Size = UDim2.new(1, -16, 0, 44)
	status.Position = UDim2.fromOffset(8, 34)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.GothamMedium
	status.TextSize = 13
	status.TextColor3 = Color3.new(1, 1, 1)
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextYAlignment = Enum.TextYAlignment.Top
	status.TextWrapped = true
	status.Text = ""
	status.Parent = panel

	local leaveButton = Instance.new("TextButton")
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

	return gui
end

local queueGui = getOrCreateQueueGui()
local panel = queueGui.Panel
local titleLabel = panel.TitleLabel
local statusLabel = panel.StatusLabel

local function formatStatus(payload)
	if payload.pending then
		return string.format(
			"%s\nArena belegt — du bist als Nächstes dran.\nSpieler in Warteschlange: %d",
			payload.modeLabel,
			payload.queued
		)
	end

	local lines = {
		string.format("%s — %d / %d Spieler", payload.modeLabel, payload.queued, payload.maxPlayers),
	}

	if payload.modeId == "ffa" and payload.fillSeconds and payload.fillSeconds > 0 then
		table.insert(lines, string.format("Match startet in %ds (oder bei %d Spielern)", payload.fillSeconds, payload.maxPlayers))
	elseif payload.queued < payload.needed then
		table.insert(lines, string.format("Warte auf %d Spieler …", payload.needed - payload.queued))
	else
		table.insert(lines, "Match wird vorbereitet …")
	end

	return table.concat(lines, "\n")
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if not payload.inQueue then
		queueGui.Enabled = false
		return
	end

	titleLabel.Text = payload.pending and "Warteschlange (Pending)" or "Warteschlange"
	statusLabel.Text = formatStatus(payload)
	queueGui.Enabled = true
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" then
		queueGui.Enabled = false
	end
end)
