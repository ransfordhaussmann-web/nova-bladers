local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = Instance.new("ScreenGui")
gui.Name = "MatchmakingQueue"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(320, 160)
frame.Position = UDim2.new(0.5, -160, 0, 24)
frame.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
frame.BorderSizePixel = 0
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 32)
title.Position = UDim2.fromOffset(10, 8)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextColor3 = Color3.fromRGB(120, 180, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "⏳ Matchmaking"
title.Parent = frame

local status = Instance.new("TextLabel")
status.Name = "Status"
status.Size = UDim2.new(1, -20, 0, 48)
status.Position = UDim2.fromOffset(10, 44)
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamMedium
status.TextSize = 14
status.TextColor3 = Color3.new(1, 1, 1)
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.Text = "Warte auf Gegner..."
status.Parent = frame

local timer = Instance.new("TextLabel")
timer.Name = "Timer"
timer.Size = UDim2.new(1, -20, 0, 22)
timer.Position = UDim2.fromOffset(10, 96)
timer.BackgroundTransparency = 1
timer.Font = Enum.Font.Gotham
timer.TextSize = 13
timer.TextColor3 = Color3.fromRGB(180, 190, 210)
timer.TextXAlignment = Enum.TextXAlignment.Left
timer.Text = ""
timer.Parent = frame

local leaveBtn = Instance.new("TextButton")
leaveBtn.Size = UDim2.fromOffset(120, 30)
leaveBtn.Position = UDim2.new(1, -130, 1, -40)
leaveBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
leaveBtn.Font = Enum.Font.GothamBold
leaveBtn.TextSize = 13
leaveBtn.TextColor3 = Color3.new(1, 1, 1)
leaveBtn.Text = "Verlassen"
leaveBtn.Parent = frame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = leaveBtn

local function formatNames(names)
	if #names == 0 then
		return "—"
	end
	if #names <= 4 then
		return table.concat(names, ", ")
	end
	return table.concat(names, ", ", 1, 4) .. (" +%d"):format(#names - 4)
end

local function showQueue(payload)
	gui.Enabled = true
	status.Text = ("Spieler: %d\nModus: %s\n%s"):format(
		payload.count or 0,
		payload.modeLabel or "Training",
		formatNames(payload.names or {})
	)
	timer.Text = payload.secondsLeft and ("Start in ~%ds"):format(payload.secondsLeft) or ""
end

Remotes.MatchmakingQueue.OnClientEvent:Connect(function(payload)
	if payload.inQueue then
		showQueue(payload)
	else
		gui.Enabled = false
	end
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		gui.Enabled = false
	elseif state.phase == "arena" then
		gui.Enabled = false
	end
end)

leaveBtn.MouseButton1Click:Connect(function()
	Remotes.LeaveQueue:FireServer()
	gui.Enabled = false
end)
