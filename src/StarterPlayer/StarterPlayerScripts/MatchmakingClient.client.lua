local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = Instance.new("ScreenGui")
gui.Name = "Matchmaking"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = playerGui

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
title.Text = "In Warteschlange..."
title.Parent = panel

local status = Instance.new("TextLabel")
status.Name = "Status"
status.Size = UDim2.new(1, -16, 0, 44)
status.Position = UDim2.fromOffset(8, 34)
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamMedium
status.TextSize = 13
status.TextColor3 = Color3.new(1, 1, 1)
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.TextWrapped = true
status.Text = ""
status.Parent = panel

local leaveButton = Instance.new("TextButton")
leaveButton.Name = "LeaveButton"
leaveButton.Size = UDim2.fromOffset(140, 30)
leaveButton.Position = UDim2.new(0.5, -70, 1, -38)
leaveButton.BackgroundColor3 = Color3.fromRGB(200, 70, 70)
leaveButton.Font = Enum.Font.GothamBold
leaveButton.TextSize = 13
leaveButton.TextColor3 = Color3.new(1, 1, 1)
leaveButton.Text = "Queue verlassen"
leaveButton.Parent = panel

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = leaveButton

local function hideLobby()
	local lobby = playerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
end

local function showLobby()
	local lobby = playerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = true
	end
end

local function formatStatus(payload)
	local lines = {
		string.format("%s — %d / %d Spieler", payload.modeLabel, payload.count, payload.maxPlayers),
	}

	if payload.status == "pending" then
		table.insert(lines, "Arena belegt — warte auf freien Slot...")
	elseif payload.status == "ready" then
		table.insert(lines, "Match startet gleich...")
	else
		table.insert(lines, string.format("Warte auf %d Spieler...", payload.minPlayers))
	end

	if #payload.players > 0 then
		table.insert(lines, "Spieler: " .. table.concat(payload.players, ", "))
	end

	return table.concat(lines, "\n")
end

local function showQueue(payload)
	hideLobby()
	gui.Enabled = true
	title.Text = "In Warteschlange"
	status.Text = formatStatus(payload)
end

local function hideQueue()
	gui.Enabled = false
	showLobby()
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	showQueue(payload)
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		hideQueue()
	elseif state.phase == "queue" or state.phase == "pending" then
		hideLobby()
		gui.Enabled = true
		if state.phase == "pending" then
			title.Text = "Arena belegt"
		else
			title.Text = "In Warteschlange"
		end
		if state.modeLabel then
			status.Text = string.format("%s\nWarte auf Mitspieler...", state.modeLabel)
		end
	elseif state.phase == "arena" then
		hideQueue()
	end
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	hideQueue()
end)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
end)
