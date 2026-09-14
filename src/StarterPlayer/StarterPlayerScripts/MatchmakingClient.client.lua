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
panel.Size = UDim2.fromOffset(300, 130)
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
leaveBtn.Size = UDim2.fromOffset(120, 30)
leaveBtn.Position = UDim2.fromOffset(8, 92)
leaveBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
leaveBtn.Font = Enum.Font.GothamBold
leaveBtn.TextSize = 13
leaveBtn.TextColor3 = Color3.new(1, 1, 1)
leaveBtn.Text = "Verlassen"
leaveBtn.Parent = panel

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = leaveBtn

local function hideQueue()
	gui.Enabled = false
end

local function showQueue()
	gui.Enabled = true
	local lobby = playerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
end

local function formatStatus(payload)
	if payload.status == "left" or payload.status == "starting" then
		return nil
	end

	local lines = {}
	table.insert(lines, string.format("Modus: %s", payload.modeLabel or "?"))
	table.insert(
		lines,
		string.format("Spieler: %d / %d", payload.playersInQueue or 0, payload.maxPlayers or 1)
	)

	if payload.status == "arena_busy" then
		table.insert(lines, "Arena belegt — du wartest…")
	elseif payload.status == "filling" then
		local secs = payload.fillSecondsLeft or 0
		table.insert(lines, string.format("Start in %ds (FFA-Fill)", secs))
	elseif payload.status == "ready" then
		table.insert(lines, "Match bereit!")
	elseif payload.minPlayers and (payload.playersInQueue or 0) < payload.minPlayers then
		table.insert(lines, string.format("Warte auf %d Spieler…", payload.minPlayers))
	else
		table.insert(lines, "Suche Gegner…")
	end

	return table.concat(lines, "\n")
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if payload.status == "left" then
		hideQueue()
		return
	end

	if payload.status == "starting" then
		hideQueue()
		return
	end

	local text = formatStatus(payload)
	if not text then
		hideQueue()
		return
	end

	title.Text = "Warteschlange — " .. (payload.modeLabel or "")
	statusLabel.Text = text
	showQueue()
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		-- Queue UI stays visible while queued; lobby returns after match
	end
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	local lobby = playerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = true
	end
end)

leaveBtn.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	hideQueue()
	local lobby = playerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = true
	end
end)
