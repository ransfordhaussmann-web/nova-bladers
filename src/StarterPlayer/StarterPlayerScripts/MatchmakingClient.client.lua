local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = Instance.new("ScreenGui")
gui.Name = "Matchmaking"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.DisplayOrder = 5
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "QueuePanel"
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

local status = Instance.new("TextLabel")
status.Name = "Status"
status.Size = UDim2.new(1, -16, 0, 44)
status.Position = UDim2.fromOffset(8, 32)
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamMedium
status.TextSize = 13
status.TextColor3 = Color3.new(1, 1, 1)
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.TextWrapped = true
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

local function formatStatus(payload)
	if payload.status == "pending" then
		return string.format(
			"%s\nArena belegt — warte auf freien Slot…",
			payload.modeLabel or payload.modeId or ""
		)
	end

	if payload.status == "starting" then
		return string.format("%s\nMatch startet…", payload.modeLabel or payload.modeId or "")
	end

	local lines = {
		string.format("%s", payload.modeLabel or payload.modeId or "Queue"),
		string.format("Spieler: %d / %d", payload.queueSize or 0, payload.maxPlayers or 1),
	}

	if payload.fillTimeout and payload.fillTimeout > 0 and payload.queueSize >= payload.minPlayers then
		local remaining = math.max(0, payload.fillTimeout - math.floor(payload.fillElapsed or 0))
		table.insert(lines, string.format("Start in ~%ds", remaining))
	end

	return table.concat(lines, "\n")
end

local function applyQueueState(payload)
	if not payload or payload.status == "idle" then
		gui.Enabled = false
		return
	end

	gui.Enabled = true
	title.Text = payload.status == "pending" and "Warteschlange (Pending)" or "Warteschlange"
	status.Text = formatStatus(payload)
	leaveBtn.Visible = payload.status ~= "starting"
end

Remotes.QueueUpdate.OnClientEvent:Connect(applyQueueState)

leaveBtn.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
end)
