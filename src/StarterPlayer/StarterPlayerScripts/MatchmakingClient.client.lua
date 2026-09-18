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
leaveButton.Size = UDim2.fromOffset(120, 30)
leaveButton.Position = UDim2.new(0.5, -60, 1, -38)
leaveButton.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
leaveButton.Font = Enum.Font.GothamBold
leaveButton.TextSize = 13
leaveButton.TextColor3 = Color3.new(1, 1, 1)
leaveButton.Text = "Verlassen"
leaveButton.Parent = panel

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = leaveButton

local function formatPlayerList(entries)
	if not entries or #entries == 0 then
		return "—"
	end
	local names = {}
	for _, entry in entries do
		table.insert(names, entry.name)
	end
	return table.concat(names, ", ")
end

local function applyQueueUpdate(payload)
	if not payload.inQueue and payload.status ~= "starting" then
		gui.Enabled = false
		return
	end

	gui.Enabled = true
	local modeLabel = payload.modeLabel or payload.modeId or "Match"
	title.Text = "Warteschlange — " .. modeLabel

	local count = payload.count or 0
	local required = payload.required or 1
	local maxPlayers = payload.maxPlayers or required
	local lines = {
		string.format("Spieler: %d / %d (min. %d)", count, maxPlayers, required),
		"Wartend: " .. formatPlayerList(payload.players),
	}

	if payload.status == "pending" then
		table.insert(lines, "Arena belegt — Match startet gleich…")
	elseif payload.status == "starting" then
		table.insert(lines, "Match startet…")
	elseif payload.fillRemaining and payload.fillRemaining > 0 then
		table.insert(lines, string.format("Start in %ds", payload.fillRemaining))
	end

	statusLabel.Text = table.concat(lines, "\n")
end

Remotes.QueueUpdate.OnClientEvent:Connect(applyQueueUpdate)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	gui.Enabled = false
end)
