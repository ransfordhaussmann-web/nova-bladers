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
title.Name = "Title"
title.Size = UDim2.new(1, -16, 0, 24)
title.Position = UDim2.fromOffset(8, 8)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextColor3 = Color3.fromRGB(120, 180, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "In Queue…"
title.Parent = panel

local status = Instance.new("TextLabel")
status.Name = "Status"
status.Size = UDim2.new(1, -16, 0, 36)
status.Position = UDim2.fromOffset(8, 32)
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamMedium
status.TextSize = 13
status.TextColor3 = Color3.new(1, 1, 1)
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.TextWrapped = true
status.Text = "Warte auf Spieler…"
status.Parent = panel

local leaveBtn = Instance.new("TextButton")
leaveBtn.Name = "LeaveButton"
leaveBtn.Size = UDim2.fromOffset(110, 28)
leaveBtn.Position = UDim2.new(1, -118, 1, -36)
leaveBtn.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
leaveBtn.Font = Enum.Font.GothamBold
leaveBtn.TextSize = 13
leaveBtn.TextColor3 = Color3.new(1, 1, 1)
leaveBtn.Text = "Verlassen"
leaveBtn.Parent = panel

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = leaveBtn

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
	local countText = string.format("%d / %d", payload.players or 0, payload.maxPlayers or 1)
	if payload.status == "pending" then
		return string.format("%s\nSpieler: %s\nArena belegt — warte…", payload.modeLabel or "Queue", countText)
	elseif payload.status == "ready" then
		return string.format("%s\nSpieler: %s\nMatch startet gleich…", payload.modeLabel or "Queue", countText)
	end
	return string.format(
		"%s\nSpieler: %s\nBenötigt: %d",
		payload.modeLabel or "Queue",
		countText,
		payload.minPlayers or 1
	)
end

local function applyQueueState(payload)
	if not payload.inQueue then
		gui.Enabled = false
		if payload.status ~= "starting" then
			showLobby()
		end
		return
	end

	hideLobby()
	gui.Enabled = true
	title.Text = "In Queue — " .. (payload.modeLabel or "Match")
	status.Text = formatStatus(payload)
end

Remotes.QueueUpdate.OnClientEvent:Connect(applyQueueState)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" and not gui.Enabled then
		showLobby()
	end
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	gui.Enabled = false
	showLobby()
end)

leaveBtn.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
end)
