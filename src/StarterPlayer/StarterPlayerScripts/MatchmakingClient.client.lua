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
panel.Position = UDim2.new(0.5, 0, 0, 16)
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
title.Size = UDim2.new(1, -16, 0, 28)
title.Position = UDim2.fromOffset(8, 8)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextColor3 = Color3.fromRGB(120, 180, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Warteschlange"
title.Parent = panel

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, -16, 0, 44)
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

local leaveCorner = Instance.new("UICorner")
leaveCorner.CornerRadius = UDim.new(0, 6)
leaveCorner.Parent = leaveButton

local function formatStatus(payload)
	if payload.status == "pending" then
		return string.format(
			"%s — Arena belegt, warte...\nSpieler in Queue: %d",
			payload.modeLabel or "Match",
			payload.playersInQueue or 0
		)
	end

	if payload.status == "starting" then
		return string.format("%s — Match startet...", payload.modeLabel or "Match")
	end

	local lines = {
		string.format("%s — Suche Gegner", payload.modeLabel or "Match"),
		string.format("Spieler in Queue: %d", payload.playersInQueue or 0),
	}

	if payload.playersNeeded and payload.playersNeeded > 0 then
		table.insert(lines, string.format("Noch benötigt: %d", payload.playersNeeded))
	end

	if payload.fillSecondsLeft and payload.fillSecondsLeft > 0 then
		table.insert(lines, string.format("Start in ~%ds", payload.fillSecondsLeft))
	end

	return table.concat(lines, "\n")
end

local function showQueue(payload)
	gui.Enabled = true
	title.Text = "Warteschlange — " .. (payload.modeLabel or "Match")
	statusLabel.Text = formatStatus(payload)
end

local function hideQueue()
	gui.Enabled = false
	statusLabel.Text = ""
end

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	hideQueue()
end)

Remotes.QueueJoin.OnClientEvent:Connect(showQueue)
Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if payload.status == "idle" then
		hideQueue()
	else
		showQueue(payload)
	end
end)
Remotes.QueueLeave.OnClientEvent:Connect(hideQueue)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" then
		hideQueue()
	end
end)
