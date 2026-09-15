local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
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
	queueGui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 16)
	panel.Size = UDim2.fromOffset(320, 110)
	panel.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	panel.Parent = queueGui

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
	title.Text = "Matchmaking"
	title.Parent = panel

	statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
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
		queueGui.Enabled = false
	end)
end

local function statusText(payload)
	local lines = {
		string.format("%s — %d / %d Spieler", payload.modeLabel, payload.count, payload.maxPlayers),
	}

	if payload.pending then
		table.insert(lines, "Arena belegt — Warte auf freien Slot…")
	elseif payload.status == "starting" and payload.fillSeconds then
		table.insert(lines, string.format("Start in %ds…", payload.fillSeconds))
	elseif payload.status == "full" then
		table.insert(lines, "Queue voll — Match startet…")
	elseif payload.count < payload.minPlayers then
		table.insert(lines, string.format("Warte auf %d+ Spieler…", payload.minPlayers))
	else
		table.insert(lines, "Bereit — warte auf Start…")
	end

	return table.concat(lines, "\n")
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	ensureGui()
	queueGui.Enabled = true
	statusLabel.Text = statusText(payload)

	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" and queueGui then
		queueGui.Enabled = false
	end
end)

Remotes.MatchState.OnClientEvent:Connect(function()
	if queueGui then
		queueGui.Enabled = false
	end
end)
