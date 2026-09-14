local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = Instance.new("ScreenGui")
gui.Name = "Matchmaking"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 12)
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

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, -16, 0, 40)
statusLabel.Position = UDim2.fromOffset(8, 34)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextSize = 13
statusLabel.TextColor3 = Color3.new(1, 1, 1)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.Text = ""
statusLabel.Parent = panel

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

local inQueue = false

local function statusText(payload)
	if payload.status == "pending" or payload.arenaBusy then
		return string.format(
			"%s — %d/%d Spieler\nArena belegt, warte auf freien Slot…",
			payload.modeLabel or payload.modeId,
			payload.count or 0,
			payload.maxPlayers or 0
		)
	end
	if payload.status == "filling" then
		return string.format(
			"%s — %d/%d Spieler\nStart in Kürze (FFA-Fill)…",
			payload.modeLabel or payload.modeId,
			payload.count or 0,
			payload.maxPlayers or 0
		)
	end
	if payload.status == "starting" then
		return string.format("%s — Match startet…", payload.modeLabel or payload.modeId)
	end
	if payload.status == "error" then
		return "Warteschlange voll oder ungültiger Modus."
	end
	return string.format(
		"%s — %d/%d Spieler\nWarte auf Gegner…",
		payload.modeLabel or payload.modeId,
		payload.count or 0,
		payload.maxPlayers or 0
	)
end

local function hideQueue()
	inQueue = false
	gui.Enabled = false
end

leaveBtn.MouseButton1Click:Connect(function()
	if inQueue then
		Remotes.QueueLeave:FireServer()
	end
	hideQueue()
end)

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if not payload.inQueue and payload.status == "left" then
		hideQueue()
		return
	end
	if payload.status == "error" then
		statusLabel.Text = statusText(payload)
		gui.Enabled = true
		task.delay(2, hideQueue)
		return
	end
	if not payload.inQueue then
		if payload.status == "starting" then
			statusLabel.Text = statusText(payload)
			gui.Enabled = true
			task.delay(1.5, hideQueue)
		end
		return
	end

	inQueue = true
	gui.Enabled = true
	title.Text = "Warteschlange — " .. (payload.modeLabel or payload.modeId)
	statusLabel.Text = statusText(payload)
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" then
		hideQueue()
	end
end)

Remotes.MatchState.OnClientEvent:Connect(function(state)
	if state.phase == "Selecting" or state.phase == "Countdown" or state.phase == "Fighting" then
		hideQueue()
	end
end)
