local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = Instance.new("ScreenGui")
gui.Name = "MatchmakingQueue"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 12)
panel.Size = UDim2.fromOffset(320, 88)
panel.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, -100, 1, -12)
statusLabel.Position = UDim2.fromOffset(12, 6)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextSize = 14
statusLabel.TextColor3 = Color3.new(1, 1, 1)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.Text = ""
statusLabel.Parent = panel

local leaveButton = Instance.new("TextButton")
leaveButton.Name = "LeaveButton"
leaveButton.Size = UDim2.fromOffset(80, 32)
leaveButton.Position = UDim2.new(1, -92, 0.5, -16)
leaveButton.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
leaveButton.Font = Enum.Font.GothamBold
leaveButton.TextSize = 13
leaveButton.TextColor3 = Color3.new(1, 1, 1)
leaveButton.Text = "Verlassen"
leaveButton.Parent = panel

local leaveCorner = Instance.new("UICorner")
leaveCorner.CornerRadius = UDim.new(0, 6)
leaveCorner.Parent = leaveButton

local function formatStatus(payload)
	local queue = payload.queue
	if not queue then
		return "Warteschlange..."
	end

	if payload.status == "pending" then
		return string.format(
			"⏳ %s — Arena belegt\nWarte auf freien Slot...",
			queue.label or queue.modeId
		)
	end

	if payload.status == "starting" then
		return string.format("▶ %s — Match startet!", queue.label or queue.modeId)
	end

	return string.format(
		"🔍 %s — %d / %d Spieler",
		queue.label or queue.modeId,
		queue.count or 0,
		queue.maxPlayers or queue.minPlayers or 1
	)
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if payload.status == "starting" then
		statusLabel.Text = formatStatus(payload)
		task.delay(1.5, function()
			gui.Enabled = false
		end)
		return
	end

	statusLabel.Text = formatStatus(payload)
	gui.Enabled = true
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" then
		gui.Enabled = false
	end
end)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	gui.Enabled = false
end)
