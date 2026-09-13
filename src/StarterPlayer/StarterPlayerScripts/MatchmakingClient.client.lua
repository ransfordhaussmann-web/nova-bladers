local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = Instance.new("ScreenGui")
gui.Name = "MatchmakingQueue"
gui.ResetOnSpawn = false
gui.DisplayOrder = 12
gui.Enabled = false
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 16)
panel.Size = UDim2.fromOffset(320, 120)
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
stroke.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(14, 10)
title.Size = UDim2.new(1, -28, 0, 24)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(180, 210, 255)
title.Text = "Warteschlange"
title.Parent = panel

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.BackgroundTransparency = 1
statusLabel.Position = UDim2.fromOffset(14, 38)
statusLabel.Size = UDim2.new(1, -28, 0, 44)
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextSize = 14
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.TextColor3 = Color3.fromRGB(220, 225, 235)
statusLabel.TextWrapped = true
statusLabel.Text = ""
statusLabel.Parent = panel

local leaveButton = Instance.new("TextButton")
leaveButton.Name = "LeaveButton"
leaveButton.AnchorPoint = Vector2.new(1, 1)
leaveButton.Position = UDim2.new(1, -12, 1, -12)
leaveButton.Size = UDim2.fromOffset(110, 30)
leaveButton.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
leaveButton.Font = Enum.Font.GothamBold
leaveButton.TextSize = 14
leaveButton.TextColor3 = Color3.new(1, 1, 1)
leaveButton.Text = "Verlassen"
leaveButton.Parent = panel

local leaveCorner = Instance.new("UICorner")
leaveCorner.CornerRadius = UDim.new(0, 6)
leaveCorner.Parent = leaveButton

local function formatStatus(payload)
	if payload.status == MatchmakingConfig.STATUS.Pending then
		return string.format(
			"%s\nSpieler: %d — Arena belegt, warte…",
			payload.modeLabel or "Match",
			payload.queueCount or 0
		)
	end
	if payload.status == MatchmakingConfig.STATUS.Starting then
		return string.format("%s\nMatch startet…", payload.modeLabel or "Match")
	end
	if payload.status == MatchmakingConfig.STATUS.Queued then
		local lines = {
			string.format("%s", payload.modeLabel or "Match"),
			string.format("Spieler in Warteschlange: %d", payload.queueCount or 0),
		}
		if payload.needed and payload.needed > 0 then
			table.insert(lines, string.format("Noch %d Spieler benötigt", payload.needed))
		elseif payload.fillRemaining then
			table.insert(lines, "Start in Kürze (FFA-Fill)")
		else
			table.insert(lines, "Bereit — warte auf Arena")
		end
		return table.concat(lines, "\n")
	end
	return ""
end

local function applyQueueState(payload)
	if not payload or payload.status == MatchmakingConfig.STATUS.Idle then
		gui.Enabled = false
		return
	end

	gui.Enabled = true
	statusLabel.Text = formatStatus(payload)

	if payload.status == MatchmakingConfig.STATUS.Starting then
		leaveButton.Visible = false
	else
		leaveButton.Visible = true
	end
end

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	gui.Enabled = false
end)

Remotes.QueueUpdate.OnClientEvent:Connect(applyQueueState)
