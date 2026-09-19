local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = Instance.new("ScreenGui")
gui.Name = "MatchmakingQueue"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.DisplayOrder = 5
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(280, 130)
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 16)
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
title.Text = "Matchmaking"
title.Parent = panel

local status = Instance.new("TextLabel")
status.Name = "Status"
status.Size = UDim2.new(1, -16, 0, 48)
status.Position = UDim2.fromOffset(8, 34)
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamMedium
status.TextSize = 14
status.TextColor3 = Color3.new(1, 1, 1)
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.TextWrapped = true
status.Text = "Warte auf Gegner…"
status.Parent = panel

local leaveBtn = Instance.new("TextButton")
leaveBtn.Name = "LeaveButton"
leaveBtn.Size = UDim2.fromOffset(120, 30)
leaveBtn.Position = UDim2.fromOffset(8, 88)
leaveBtn.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
leaveBtn.Font = Enum.Font.GothamBold
leaveBtn.TextSize = 13
leaveBtn.TextColor3 = Color3.new(1, 1, 1)
leaveBtn.Text = "Queue verlassen"
leaveBtn.Parent = panel

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = leaveBtn

local function formatStatus(payload)
	if payload.status == "left" then
		return nil
	end

	local lines = {}
	if payload.modeLabel then
		table.insert(lines, payload.modeLabel)
	end

	local countText = string.format("%d / %d Spieler", payload.queueSize or 0, payload.minPlayers or 1)
	if payload.maxPlayers and payload.maxPlayers > payload.minPlayers then
		countText = string.format("%d / %d–%d Spieler", payload.queueSize or 0, payload.minPlayers or 2, payload.maxPlayers)
	end
	table.insert(lines, countText)

	if payload.pending then
		table.insert(lines, "Arena belegt — wartet…")
	elseif payload.status == "filling" then
		table.insert(lines, "FFA startet bald…")
	elseif payload.status == "ready" then
		table.insert(lines, "Match startet…")
	else
		table.insert(lines, "Warte auf Gegner…")
	end

	return table.concat(lines, "\n")
end

local function showQueue(payload)
	local text = formatStatus(payload)
	if not text then
		gui.Enabled = false
		return
	end

	title.Text = "In Queue"
	status.Text = text
	gui.Enabled = true

	local lobby = playerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if payload.status == "left" then
		gui.Enabled = false
		return
	end
	showQueue(payload)
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		gui.Enabled = false
	elseif state.phase == "queue" then
		showQueue({
			modeLabel = state.modeLabel,
			queueSize = 1,
			minPlayers = 1,
			status = "waiting",
		})
	elseif state.phase == "arena" then
		gui.Enabled = false
	end
end)

leaveBtn.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	gui.Enabled = false
	Remotes.ReturnToHub:FireServer()
end)
