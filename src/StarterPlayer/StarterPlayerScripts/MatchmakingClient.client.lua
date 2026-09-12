local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = playerGui:FindFirstChild("MatchmakingQueue")
if not gui then
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
	panel.Size = UDim2.fromOffset(320, 110)
	panel.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "TitleLabel"
	title.Size = UDim2.new(1, -16, 0, 22)
	title.Position = UDim2.fromOffset(8, 8)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 15
	title.TextColor3 = Color3.fromRGB(120, 180, 255)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Matchmaking"
	title.Parent = panel

	local status = Instance.new("TextLabel")
	status.Name = "StatusLabel"
	status.Size = UDim2.new(1, -16, 0, 40)
	status.Position = UDim2.fromOffset(8, 32)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.GothamMedium
	status.TextSize = 13
	status.TextColor3 = Color3.new(1, 1, 1)
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextYAlignment = Enum.TextYAlignment.Top
	status.Text = "Warte auf Spieler..."
	status.Parent = panel

	local leaveBtn = Instance.new("TextButton")
	leaveBtn.Name = "LeaveButton"
	leaveBtn.Size = UDim2.fromOffset(120, 28)
	leaveBtn.Position = UDim2.new(1, -128, 1, -36)
	leaveBtn.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
	leaveBtn.Font = Enum.Font.GothamBold
	leaveBtn.TextSize = 13
	leaveBtn.TextColor3 = Color3.new(1, 1, 1)
	leaveBtn.Text = "Verlassen"
	leaveBtn.Parent = panel

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = leaveBtn
end

local panel = gui:WaitForChild("Panel")
local titleLabel = panel:WaitForChild("TitleLabel")
local statusLabel = panel:WaitForChild("StatusLabel")
local leaveButton = panel:WaitForChild("LeaveButton")

local STATUS_TEXT = {
	waiting = "Warte auf Mitspieler...",
	pending = "Arena belegt — du bist in der Warteschlange",
	filling = "Fast voll — Match startet bald",
	ready = "Match bereit!",
	starting = "Match startet...",
}

local function hideQueue()
	gui.Enabled = false
end

local function showQueue(payload)
	gui.Enabled = true
	titleLabel.Text = "Queue: " .. (payload.modeLabel or payload.modeId or "?")

	local statusKey = payload.status or "waiting"
	local baseText = STATUS_TEXT[statusKey] or STATUS_TEXT.waiting

	if payload.inQueue and payload.minPlayers then
		statusLabel.Text = string.format(
			"%s\n%d / %d Spieler",
			baseText,
			payload.inQueue,
			payload.maxPlayers or payload.minPlayers
		)
	else
		statusLabel.Text = baseText
	end
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if not payload or payload.status == "idle" then
		hideQueue()
		return
	end

	if payload.status == "starting" then
		showQueue(payload)
		task.delay(2, hideQueue)
		return
	end

	showQueue(payload)
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" then
		hideQueue()
	end
end)

Remotes.MatchState.OnClientEvent:Connect(function(matchState)
	if matchState.phase == "Selecting" or matchState.phase == "Countdown" or matchState.phase == "Fighting" then
		hideQueue()
	end
end)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	hideQueue()
end)
