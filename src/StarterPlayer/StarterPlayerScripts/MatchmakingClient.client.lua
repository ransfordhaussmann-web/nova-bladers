local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = Instance.new("ScreenGui")
gui.Name = "Matchmaking"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Name = "QueuePanel"
frame.Size = UDim2.fromOffset(300, 120)
frame.Position = UDim2.new(0.5, -150, 0, 80)
frame.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
frame.BackgroundTransparency = 0.1
frame.BorderSizePixel = 0
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -16, 0, 28)
title.Position = UDim2.fromOffset(8, 8)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextColor3 = Color3.fromRGB(120, 180, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Warteschlange"
title.Parent = frame

local status = Instance.new("TextLabel")
status.Name = "Status"
status.Size = UDim2.new(1, -16, 0, 44)
status.Position = UDim2.fromOffset(8, 36)
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamMedium
status.TextSize = 14
status.TextColor3 = Color3.new(1, 1, 1)
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.Text = ""
status.Parent = frame

local leaveBtn = Instance.new("TextButton")
leaveBtn.Name = "LeaveButton"
leaveBtn.Size = UDim2.fromOffset(100, 28)
leaveBtn.Position = UDim2.new(1, -108, 1, -36)
leaveBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
leaveBtn.Font = Enum.Font.GothamBold
leaveBtn.TextSize = 13
leaveBtn.TextColor3 = Color3.new(1, 1, 1)
leaveBtn.Text = "Verlassen"
leaveBtn.Parent = frame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = leaveBtn

local MODE_LABELS = {
	training = "Training",
	pvp = "1v1 PvP",
	ffa = "FFA",
	quick = "Quick Match",
}

local function formatStatus(payload)
	if not payload or not payload.inQueue then
		return nil
	end

	local modeLabel = payload.modeLabel or MODE_LABELS[payload.modeId] or payload.modeId
	local count = payload.playersInQueue or 0
	local minPlayers = payload.minPlayers or 1
	local timeLeft = payload.timeLeft or 0
	local effective = MODE_LABELS[payload.effectiveMode] or payload.effectiveMode

	local lines = {
		modeLabel,
		string.format("%d / %d Spieler", count, minPlayers),
	}
	if payload.modeId == "quick" then
		table.insert(lines, string.format("Modus bei Start: %s", effective))
	end
	table.insert(lines, string.format("~%ds verbleibend", timeLeft))
	return table.concat(lines, "\n")
end

leaveBtn.MouseButton1Click:Connect(function()
	Remotes.MatchmakingLeave:FireServer()
	gui.Enabled = false
end)

Remotes.MatchmakingUpdate.OnClientEvent:Connect(function(payload)
	if not payload or payload.inQueue == false or not payload.modeId then
		gui.Enabled = false
		return
	end

	local text = formatStatus(payload)
	if text then
		status.Text = text
		gui.Enabled = true
	end
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" then
		gui.Enabled = false
	end
end)

Remotes.MatchState.OnClientEvent:Connect(function(payload)
	if payload.phase ~= "Idle" and payload.phase ~= "Selecting" then
		gui.Enabled = false
	end
end)
