local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = Instance.new("ScreenGui")
gui.Name = "MatchmakingQueue"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 12)
panel.Size = UDim2.fromOffset(300, 120)
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
title.Text = "Matchmaking"
title.Parent = panel

local status = Instance.new("TextLabel")
status.Name = "StatusLabel"
status.Size = UDim2.new(1, -16, 0, 52)
status.Position = UDim2.fromOffset(8, 34)
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

local function formatStatus(payload)
	if payload.error == "queue_full" then
		return "Queue ist voll. Bitte später erneut versuchen."
	end

	local lines = {
		string.format("Modus: %s", payload.modeLabel or payload.modeId or "?"),
		string.format("Spieler: %d / %d", payload.queued or 0, payload.maxPlayers or 0),
	}

	if payload.status == "pending" then
		table.insert(lines, "Arena belegt — warte auf freien Slot")
	elseif payload.status == "starting" then
		table.insert(lines, "Match startet...")
	else
		table.insert(lines, string.format("Warte auf %d Spieler", math.max(0, (payload.minPlayers or 1) - (payload.queued or 0))))
	end

	if payload.players and #payload.players > 0 then
		table.insert(lines, "In Queue: " .. table.concat(payload.players, ", "))
	end

	return table.concat(lines, "\n")
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if payload.inQueue == false or payload.error then
		gui.Enabled = false
		if payload.error == "queue_full" then
			gui.Enabled = true
			title.Text = "Matchmaking"
			status.Text = formatStatus(payload)
			task.delay(2.5, function()
				gui.Enabled = false
			end)
		end
		return
	end

	gui.Enabled = true
	title.Text = "In Queue"
	status.Text = formatStatus(payload)
end)

Remotes.MatchState.OnClientEvent:Connect(function()
	gui.Enabled = false
end)

leaveBtn.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	gui.Enabled = false
end)
