local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = Instance.new("ScreenGui")
gui.Name = "Matchmaking"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "QueuePanel"
panel.Size = UDim2.fromOffset(280, 120)
panel.Position = UDim2.new(0.5, -140, 0, 72)
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
title.Text = "Matchmaking"
title.Parent = panel

local status = Instance.new("TextLabel")
status.Name = "StatusLabel"
status.Size = UDim2.new(1, -16, 0, 44)
status.Position = UDim2.fromOffset(8, 34)
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
leaveBtn.Position = UDim2.fromOffset(8, 84)
leaveBtn.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
leaveBtn.Font = Enum.Font.GothamBold
leaveBtn.TextSize = 13
leaveBtn.TextColor3 = Color3.new(1, 1, 1)
leaveBtn.Text = "Queue verlassen"
leaveBtn.Parent = panel

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = leaveBtn

local function formatStatus(payload)
	if payload.leftQueue then
		return ""
	end
	if not payload.inQueue then
		return ""
	end

	local lines = {
		string.format("%s — %d / %d Spieler", payload.modeLabel or payload.modeId, payload.count or 0, payload.minPlayers or 1),
	}
	if payload.pending then
		table.insert(lines, "Arena belegt — warte...")
	elseif payload.fillSecondsLeft and payload.fillSecondsLeft > 0 then
		table.insert(lines, string.format("Start in %ds (max. %d)", payload.fillSecondsLeft, payload.maxPlayers or payload.minPlayers))
	elseif (payload.count or 0) < (payload.minPlayers or 1) then
		local needed = (payload.minPlayers or 1) - (payload.count or 0)
		table.insert(lines, string.format("Noch %d Spieler nötig", needed))
	else
		table.insert(lines, "Match startet gleich...")
	end
	return table.concat(lines, "\n")
end

local function applyQueueUpdate(payload)
	if payload.leftQueue or not payload.inQueue then
		gui.Enabled = false
		status.Text = ""
		return
	end

	gui.Enabled = true
	title.Text = "In Queue: " .. (payload.modeLabel or payload.modeId)
	status.Text = formatStatus(payload)
end

Remotes.QueueUpdate.OnClientEvent:Connect(applyQueueUpdate)

leaveBtn.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" then
		gui.Enabled = false
	end
end)
