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
panel.Name = "QueuePanel"
panel.Size = UDim2.fromOffset(300, 140)
panel.Position = UDim2.new(0.5, -150, 0, 80)
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

local status = Instance.new("TextLabel")
status.Name = "Status"
status.Size = UDim2.new(1, -16, 0, 52)
status.Position = UDim2.fromOffset(8, 36)
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamMedium
status.TextSize = 14
status.TextColor3 = Color3.new(1, 1, 1)
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.TextWrapped = true
status.Text = ""
status.Parent = panel

local leaveBtn = Instance.new("TextButton")
leaveBtn.Name = "LeaveButton"
leaveBtn.Size = UDim2.fromOffset(120, 32)
leaveBtn.Position = UDim2.new(0.5, -60, 1, -44)
leaveBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
leaveBtn.Font = Enum.Font.GothamBold
leaveBtn.TextSize = 13
leaveBtn.TextColor3 = Color3.new(1, 1, 1)
leaveBtn.Text = "Verlassen"
leaveBtn.Parent = panel

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = leaveBtn

local function hideLobby()
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
end

local function showLobby()
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = true
	end
end

local function formatStatus(payload)
	if payload.pending then
		return string.format(
			"%s\nMatch bereit — Arena belegt\nWarte auf freien Slot…",
			payload.modeLabel or "Match"
		)
	end

	local lines = {
		payload.modeLabel or "Match",
		string.format("Spieler: %d / %d", payload.total or 0, payload.maxPlayers or 0),
	}

	if payload.fillTimeLeft then
		table.insert(lines, string.format("Start in %ds…", payload.fillTimeLeft))
	elseif payload.total and payload.minPlayers and payload.total < payload.minPlayers then
		table.insert(lines, string.format("Noch %d Spieler nötig", payload.minPlayers - payload.total))
	else
		table.insert(lines, "Suche Gegner…")
	end

	return table.concat(lines, "\n")
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if payload.cleared then
		gui.Enabled = false
		showLobby()
		return
	end

	hideLobby()
	gui.Enabled = true
	title.Text = if payload.pending then "Match ausstehend" else "Warteschlange"
	status.Text = formatStatus(payload)
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		gui.Enabled = false
		showLobby()
	elseif state.phase == "arena" then
		gui.Enabled = false
	end
end)

leaveBtn.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
end)
