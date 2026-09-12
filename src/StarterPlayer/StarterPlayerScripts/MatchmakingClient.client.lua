local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchState = require(ReplicatedStorage.NovaBladers.MatchState)

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
panel.Size = UDim2.fromOffset(320, 96)
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

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, -120, 0, 40)
statusLabel.Position = UDim2.fromOffset(8, 34)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextSize = 13
statusLabel.TextColor3 = Color3.new(1, 1, 1)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.Text = ""
statusLabel.Parent = panel

local leaveButton = Instance.new("TextButton")
leaveButton.Name = "LeaveButton"
leaveButton.Size = UDim2.fromOffset(96, 32)
leaveButton.Position = UDim2.new(1, -104, 1, -40)
leaveButton.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
leaveButton.Font = Enum.Font.GothamBold
leaveButton.TextSize = 13
leaveButton.TextColor3 = Color3.new(1, 1, 1)
leaveButton.Text = "Verlassen"
leaveButton.Parent = panel

local leaveCorner = Instance.new("UICorner")
leaveCorner.CornerRadius = UDim.new(0, 6)
leaveCorner.Parent = leaveButton

local activeModeId = "training"

local function formatStatus(payload)
	local countText = string.format("%d / %d Spieler", payload.queueCount or 0, payload.maxPlayers or 1)
	local modeLabel = payload.modeLabel or "Queue"

	if payload.status == MatchState.QueueStatus.Pending then
		return string.format("%s\n%s — Arena belegt, warte...", modeLabel, countText)
	end
	if payload.status == MatchState.QueueStatus.Ready then
		return string.format("%s\n%s — Match startet!", modeLabel, countText)
	end
	if payload.fillSeconds and payload.fillSeconds > 0 then
		return string.format("%s\n%s — Start in %ds", modeLabel, countText, payload.fillSeconds)
	end
	return string.format("%s\n%s — Suche Gegner...", modeLabel, countText)
end

local function showQueue(payload)
	if not payload.inQueue and payload.status == MatchState.QueueStatus.Idle then
		gui.Enabled = false
		return
	end

	gui.Enabled = true
	title.Text = "Matchmaking — " .. (payload.modeLabel or "Queue")
	statusLabel.Text = formatStatus(payload)
end

Remotes.QueueUpdate.OnClientEvent:Connect(showQueue)

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if payload.activeModeId then
		activeModeId = payload.activeModeId
	end
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		gui.Enabled = gui.Enabled
	elseif state.phase == "arena" then
		gui.Enabled = false
	end
end)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	gui.Enabled = false
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	gui.Enabled = false
end)
