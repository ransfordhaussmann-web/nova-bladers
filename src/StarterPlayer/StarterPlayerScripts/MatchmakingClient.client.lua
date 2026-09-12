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
panel.Size = UDim2.fromOffset(300, 110)
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
title.Text = "Warteschlange"
title.Parent = panel

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, -16, 0, 44)
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

local leaveButton = Instance.new("TextButton")
leaveButton.Name = "LeaveButton"
leaveButton.Size = UDim2.fromOffset(120, 28)
leaveButton.Position = UDim2.fromOffset(8, 74)
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
	local countText = string.format("%d / %d", payload.playersInQueue, payload.maxPlayers)
	if payload.status == "pending" then
		return string.format("%s\nArena belegt — warte...\nSpieler: %s", payload.modeLabel, countText)
	elseif payload.status == "filling" then
		return string.format("%s\nSuche weitere Spieler...\nSpieler: %s", payload.modeLabel, countText)
	elseif payload.status == "ready" then
		return string.format("%s\nMatch startet gleich...\nSpieler: %s", payload.modeLabel, countText)
	elseif payload.status == "starting" then
		return string.format("%s\nMatch startet!", payload.modeLabel)
	end

	local needed = math.max(0, payload.playersNeeded - payload.playersInQueue)
	if needed > 0 then
		return string.format(
			"%s\nWarte auf %d weitere(n) Spieler...\nIn Queue: %s",
			payload.modeLabel,
			needed,
			countText
		)
	end
	return string.format("%s\nSpieler: %s", payload.modeLabel, countText)
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if payload.status == "starting" then
		statusLabel.Text = formatStatus(payload)
		task.delay(1, function()
			gui.Enabled = false
		end)
		return
	end

	gui.Enabled = true
	title.Text = "Warteschlange — " .. (payload.modeLabel or "Arena")
	statusLabel.Text = formatStatus(payload)
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		gui.Enabled = false
	elseif state.phase == "arena" then
		gui.Enabled = false
	end
end)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	gui.Enabled = false
end)
