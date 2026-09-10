local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local queueGui
local queuePanel
local queueTitle
local queueStatus
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

	queuePanel = Instance.new("Frame")
	queuePanel.Name = "Panel"
	queuePanel.Size = UDim2.fromOffset(280, 120)
	queuePanel.Position = UDim2.new(0.5, -140, 0, 80)
	queuePanel.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	queuePanel.BackgroundTransparency = 0.1
	queuePanel.BorderSizePixel = 0
	queuePanel.Parent = queueGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = queuePanel

	queueTitle = Instance.new("TextLabel")
	queueTitle.Name = "Title"
	queueTitle.Size = UDim2.new(1, -16, 0, 24)
	queueTitle.Position = UDim2.fromOffset(8, 8)
	queueTitle.BackgroundTransparency = 1
	queueTitle.Font = Enum.Font.GothamBold
	queueTitle.TextSize = 16
	queueTitle.TextColor3 = Color3.fromRGB(120, 180, 255)
	queueTitle.TextXAlignment = Enum.TextXAlignment.Left
	queueTitle.Text = "Warteschlange"
	queueTitle.Parent = queuePanel

	queueStatus = Instance.new("TextLabel")
	queueStatus.Name = "Status"
	queueStatus.Size = UDim2.new(1, -16, 0, 52)
	queueStatus.Position = UDim2.fromOffset(8, 34)
	queueStatus.BackgroundTransparency = 1
	queueStatus.Font = Enum.Font.GothamMedium
	queueStatus.TextSize = 13
	queueStatus.TextColor3 = Color3.new(1, 1, 1)
	queueStatus.TextXAlignment = Enum.TextXAlignment.Left
	queueStatus.TextYAlignment = Enum.TextYAlignment.Top
	queueStatus.TextWrapped = true
	queueStatus.Text = ""
	queueStatus.Parent = queuePanel

	leaveButton = Instance.new("TextButton")
	leaveButton.Name = "LeaveButton"
	leaveButton.Size = UDim2.fromOffset(120, 28)
	leaveButton.Position = UDim2.new(1, -128, 1, -36)
	leaveButton.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
	leaveButton.Font = Enum.Font.GothamBold
	leaveButton.TextSize = 13
	leaveButton.TextColor3 = Color3.new(1, 1, 1)
	leaveButton.Text = "Verlassen"
	leaveButton.Parent = queuePanel

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = leaveButton

	leaveButton.MouseButton1Click:Connect(function()
		Remotes.QueueLeave:FireServer()
	end)
end

local function formatStatus(payload)
	local lines = {
		string.format("%s — %d/%d Spieler", payload.modeLabel, payload.players, payload.maxPlayers),
	}

	if payload.status == "pending" then
		table.insert(lines, "Arena belegt — warte...")
	elseif payload.status == "starting" and payload.fillRemaining then
		table.insert(lines, string.format("Start in %ds", math.ceil(payload.fillRemaining)))
	elseif payload.status == "ready" or payload.status == "full" then
		table.insert(lines, "Match startet gleich...")
	else
		table.insert(lines, string.format("Noch %d Spieler nötig", math.max(0, payload.minPlayers - payload.players)))
	end

	return table.concat(lines, "\n")
end

local function showQueue(payload)
	ensureGui()
	queueTitle.Text = "Warteschlange: " .. payload.modeLabel
	queueStatus.Text = formatStatus(payload)
	queueGui.Enabled = true
end

local function hideQueue()
	if queueGui then
		queueGui.Enabled = false
	end
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if payload then
		showQueue(payload)
	else
		hideQueue()
	end
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" then
		hideQueue()
	end
end)

Remotes.MatchState.OnClientEvent:Connect(function()
	hideQueue()
end)
