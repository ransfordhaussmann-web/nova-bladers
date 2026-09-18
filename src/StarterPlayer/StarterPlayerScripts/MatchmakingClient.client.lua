local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local queueGui = Instance.new("ScreenGui")
queueGui.Name = "MatchmakingQueue"
queueGui.ResetOnSpawn = false
queueGui.Enabled = false
queueGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(280, 120)
panel.Position = UDim2.new(0.5, -140, 0, 80)
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
title.TextSize = 15
title.TextColor3 = Color3.fromRGB(120, 180, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "⏳ Warte auf Match..."
title.Parent = panel

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, -16, 0, 48)
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

local leaveBtn = Instance.new("TextButton")
leaveBtn.Name = "LeaveButton"
leaveBtn.Size = UDim2.fromOffset(120, 28)
leaveBtn.Position = UDim2.fromOffset(8, 84)
leaveBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
leaveBtn.Font = Enum.Font.GothamBold
leaveBtn.TextSize = 13
leaveBtn.TextColor3 = Color3.new(1, 1, 1)
leaveBtn.Text = "Queue verlassen"
leaveBtn.Parent = panel

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = leaveBtn

local function formatStatus(payload)
	if payload.status == "idle" then
		return nil
	end

	local lines = {}
	local modeLabel = payload.modeLabel or payload.modeId or "?"
	table.insert(lines, string.format("Modus: %s", modeLabel))
	table.insert(lines, string.format("Spieler: %d / %d", payload.queueSize or 0, payload.maxPlayers or 1))

	if payload.status == "pending" then
		table.insert(lines, "Arena belegt — warte...")
	elseif payload.status == "filling" then
		table.insert(lines, string.format("Füllt sich (%ds)...", payload.fillTimeout or 12))
	elseif payload.status == "ready" then
		table.insert(lines, "Match startet gleich!")
	else
		table.insert(lines, "Warte auf Spieler...")
	end

	if payload.players and #payload.players > 0 then
		table.insert(lines, table.concat(payload.players, ", "))
	end

	return table.concat(lines, "\n")
end

local function showQueue(payload)
	local text = formatStatus(payload)
	if not text then
		queueGui.Enabled = false
		return
	end

	title.Text = payload.pending
		and "⏳ Arena belegt"
		or "⏳ In der Queue"
	statusLabel.Text = text
	queueGui.Enabled = true
end

leaveBtn.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	queueGui.Enabled = false
end)

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if payload.status == "idle" then
		queueGui.Enabled = false
	else
		showQueue(payload)
	end
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" then
		queueGui.Enabled = false
	end
end)
