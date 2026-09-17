local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local queueGui = Instance.new("ScreenGui")
queueGui.Name = "MatchmakingQueue"
queueGui.ResetOnSpawn = false
queueGui.DisplayOrder = 20
queueGui.Enabled = false
queueGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 12)
panel.Size = UDim2.fromOffset(320, 88)
panel.BackgroundColor3 = Color3.fromRGB(22, 26, 36)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Parent = queueGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(12, 8)
title.Size = UDim2.new(1, -24, 0, 22)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextColor3 = Color3.fromRGB(180, 220, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Warteschlange"
title.Parent = panel

local status = Instance.new("TextLabel")
status.Name = "Status"
status.BackgroundTransparency = 1
status.Position = UDim2.fromOffset(12, 32)
status.Size = UDim2.new(1, -24, 0, 36)
status.Font = Enum.Font.GothamMedium
status.TextSize = 14
status.TextColor3 = Color3.fromRGB(220, 220, 230)
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.TextWrapped = true
status.Text = ""
status.Parent = panel

local leaveButton = Instance.new("TextButton")
leaveButton.Name = "LeaveButton"
leaveButton.AnchorPoint = Vector2.new(1, 1)
leaveButton.Position = UDim2.new(1, -12, 1, -10)
leaveButton.Size = UDim2.fromOffset(110, 28)
leaveButton.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
leaveButton.Font = Enum.Font.GothamBold
leaveButton.TextSize = 14
leaveButton.TextColor3 = Color3.new(1, 1, 1)
leaveButton.Text = "Verlassen"
leaveButton.Parent = panel

local leaveCorner = Instance.new("UICorner")
leaveCorner.CornerRadius = UDim.new(0, 6)
leaveCorner.Parent = leaveButton

local function hideQueue()
	queueGui.Enabled = false
end

local function showQueue(payload)
	if not payload.inQueue then
		hideQueue()
		return
	end

	local countText = string.format("%d / %d", payload.queued or 0, payload.maxPlayers or 1)
	local lines = {
		string.format("%s — %s Spieler", payload.modeLabel or "Modus", countText),
	}

	if payload.pending then
		table.insert(lines, "Arena belegt — warte auf freien Slot...")
	elseif (payload.queued or 0) < (payload.minPlayers or 1) then
		table.insert(lines, string.format("Warte auf %d Spieler...", (payload.minPlayers or 1) - (payload.queued or 0)))
	else
		table.insert(lines, "Match startet gleich...")
	end

	if payload.pending then
		title.Text = "Warteschlange (Pending)"
	else
		title.Text = "Warteschlange"
	end
	status.Text = table.concat(lines, "\n")
	queueGui.Enabled = true
end

Remotes.QueueUpdate.OnClientEvent:Connect(showQueue)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" then
		hideQueue()
	end
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	hideQueue()
end)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	hideQueue()
end)
