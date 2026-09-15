local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local QueueJoin = Remotes:WaitForChild("QueueJoin")
local QueueLeave = Remotes:WaitForChild("QueueLeave")
local QueueUpdate = Remotes:WaitForChild("QueueUpdate")

local gui = Instance.new("ScreenGui")
gui.Name = "MatchmakingQueue"
gui.ResetOnSpawn = false
gui.DisplayOrder = 12
gui.Enabled = false
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 12)
panel.Size = UDim2.fromOffset(320, 132)
panel.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(80, 140, 255)
stroke.Thickness = 1.5
stroke.Transparency = 0.35
stroke.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(14, 10)
title.Size = UDim2.new(1, -28, 0, 22)
title.Font = Enum.Font.GothamBold
title.TextSize = 17
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(220, 230, 255)
title.Text = "Matchmaking"
title.Parent = panel

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.BackgroundTransparency = 1
statusLabel.Position = UDim2.fromOffset(14, 36)
statusLabel.Size = UDim2.new(1, -28, 0, 44)
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextSize = 14
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.TextColor3 = Color3.fromRGB(180, 190, 210)
statusLabel.TextWrapped = true
statusLabel.Text = ""
statusLabel.Parent = panel

local leaveButton = Instance.new("TextButton")
leaveButton.Name = "LeaveButton"
leaveButton.AnchorPoint = Vector2.new(1, 1)
leaveButton.Position = UDim2.new(1, -14, 1, -12)
leaveButton.Size = UDim2.fromOffset(120, 30)
leaveButton.BackgroundColor3 = Color3.fromRGB(180, 60, 70)
leaveButton.Font = Enum.Font.GothamBold
leaveButton.TextSize = 14
leaveButton.TextColor3 = Color3.new(1, 1, 1)
leaveButton.Text = "Verlassen"
leaveButton.Parent = panel

local leaveCorner = Instance.new("UICorner")
leaveCorner.CornerRadius = UDim.new(0, 6)
leaveCorner.Parent = leaveButton

local function formatStatus(payload)
	if payload.status == "pending" then
		return "Arena belegt — du bist als Nächster dran."
	end

	local line = string.format(
		"%s: %d / %d Spieler",
		payload.modeLabel or payload.modeId or "Queue",
		payload.queuedCount or 0,
		payload.minPlayers or 1
	)

	if payload.players and #payload.players > 0 then
		line ..= "\n" .. table.concat(payload.players, ", ")
	end

	if payload.modeId == "ffa" and (payload.queuedCount or 0) < (payload.minPlayers or 3) then
		line ..= "\nWarte auf weitere Spieler (max. 12s)…"
	end

	return line
end

QueueUpdate.OnClientEvent:Connect(function(payload)
	if payload.inQueue == false then
		gui.Enabled = false
		return
	end

	gui.Enabled = true
	title.Text = "⏳ " .. (payload.modeLabel or "Matchmaking")
	statusLabel.Text = formatStatus(payload)
end)

leaveButton.MouseButton1Click:Connect(function()
	QueueLeave:FireServer()
	gui.Enabled = false
end)
