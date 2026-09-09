local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui
local panel
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
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 72)
	panel.Size = UDim2.fromOffset(320, 120)
	panel.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -16, 0, 24)
	title.Position = UDim2.fromOffset(8, 8)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextColor3 = Color3.fromRGB(120, 180, 255)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Warteschlange"
	title.Parent = panel

	statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, -16, 0, 52)
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

local function formatStatus(payload)
	if payload.status == "left" then
		return nil
	end

	local lines = {
		string.format("Modus: %s", payload.modeLabel or payload.modeId or "?"),
		string.format("Spieler: %d / %d", payload.queueSize or 0, payload.required or 1),
	}

	if payload.maxPlayers and payload.maxPlayers > payload.required then
		lines[2] = string.format(
			"Spieler: %d / %d (max %d)",
			payload.queueSize or 0,
			payload.required or 1,
			payload.maxPlayers
		)
	end

	if payload.status == "pending" then
		table.insert(lines, "Arena belegt — warte auf freien Slot")
	else
		table.insert(lines, string.format("Position: %d", payload.position or 1))
	end

	return table.concat(lines, "\n")
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	ensureGui()

	if payload.status == "left" then
		gui.Enabled = false
		return
	end

	local text = formatStatus(payload)
	if not text then
		gui.Enabled = false
		return
	end

	statusLabel.Text = text
	gui.Enabled = true
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" and gui then
		gui.Enabled = false
	end
end)
