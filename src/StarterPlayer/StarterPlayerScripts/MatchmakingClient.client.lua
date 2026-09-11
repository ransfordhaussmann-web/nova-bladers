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
panel.Size = UDim2.fromOffset(280, 130)
panel.Position = UDim2.new(0.5, -140, 0, 16)
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
title.Text = "⏳ Warteschlange"
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
statusLabel.Text = "Suche Mitspieler..."
statusLabel.Parent = panel

local leaveBtn = Instance.new("TextButton")
leaveBtn.Name = "LeaveButton"
leaveBtn.Size = UDim2.fromOffset(100, 28)
leaveBtn.Position = UDim2.new(1, -108, 1, -36)
leaveBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
leaveBtn.Font = Enum.Font.GothamBold
leaveBtn.TextSize = 13
leaveBtn.TextColor3 = Color3.new(1, 1, 1)
leaveBtn.Text = "Verlassen"
leaveBtn.Parent = panel

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = leaveBtn

local STATUS_TEXT = {
	waiting = "Warte auf Mitspieler...",
	filling = "Arena füllt sich — Start in %ds",
	pending = "Match bereit — Arena noch belegt",
	starting = "Match startet gleich!",
	left = "",
}

local function formatStatus(payload)
	local base = STATUS_TEXT[payload.status] or "In Warteschlange..."
	if payload.status == "filling" and payload.fillTimeLeft then
		base = string.format(STATUS_TEXT.filling, payload.fillTimeLeft)
	end
	local countLine = string.format("%d / %d Spieler", payload.count or 0, payload.max or 1)
	local playersLine = ""
	if payload.players and #payload.players > 0 then
		playersLine = table.concat(payload.players, ", ")
	end
	return string.format("%s\n%s\n%s", payload.modeLabel or "", countLine, playersLine), base
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if payload.status == "left" then
		gui.Enabled = false
		return
	end

	local detail, statusText = formatStatus(payload)
	statusLabel.Text = detail
	title.Text = "⏳ " .. (statusText or "Warteschlange")
	gui.Enabled = true
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" then
		gui.Enabled = false
	end
end)

Remotes.MatchState.OnClientEvent:Connect(function()
	gui.Enabled = false
end)

leaveBtn.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	gui.Enabled = false
end)
