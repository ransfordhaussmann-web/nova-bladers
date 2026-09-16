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
status.Name = "StatusLabel"
status.Size = UDim2.new(1, -16, 0, 36)
status.Position = UDim2.fromOffset(8, 32)
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamMedium
status.TextSize = 13
status.TextColor3 = Color3.new(1, 1, 1)
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.Text = ""
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
		string.format("%s — %d / %d Spieler", payload.modeLabel or payload.modeId, payload.count or 0, payload.maxPlayers or 1),
	}
	if payload.pending then
		table.insert(lines, "Arena belegt — warte auf freies Match...")
	elseif payload.fillTimeout and payload.fillTimeout > 0 and payload.count >= payload.minPlayers then
		table.insert(lines, string.format("Start in bis zu %ds...", payload.fillTimeout))
	else
		table.insert(lines, string.format("Noch %d Spieler benötigt", math.max(0, (payload.minPlayers or 1) - (payload.count or 0))))
	end
	return table.concat(lines, "\n")
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if not payload.inQueue then
		gui.Enabled = false
		showLobby()
		return
	end

	hideLobby()
	gui.Enabled = true
	title.Text = payload.pending and "Warteschlange (Pending)" or "In Warteschlange"
	status.Text = formatStatus(payload)
end)

leaveBtn.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	gui.Enabled = false
	showLobby()
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" and not gui.Enabled then
		showLobby()
	elseif state.phase == "arena" then
		gui.Enabled = false
	end
end)

Remotes.MatchState.OnClientEvent:Connect(function()
	gui.Enabled = false
end)
