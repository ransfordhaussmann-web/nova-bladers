local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = Instance.new("ScreenGui")
gui.Name = "MatchQueue"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(320, 200)
frame.Position = UDim2.new(0.5, -160, 0.5, -100)
frame.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
frame.BorderSizePixel = 0
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 36)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextColor3 = Color3.new(1, 1, 1)
title.Text = "Matchmaking-Warteschlange"
title.Parent = frame

local modeLabel = Instance.new("TextLabel")
modeLabel.Name = "ModeLabel"
modeLabel.Size = UDim2.new(1, -20, 0, 22)
modeLabel.Position = UDim2.fromOffset(10, 40)
modeLabel.BackgroundTransparency = 1
modeLabel.Font = Enum.Font.GothamMedium
modeLabel.TextSize = 14
modeLabel.TextColor3 = Color3.fromRGB(120, 180, 255)
modeLabel.TextXAlignment = Enum.TextXAlignment.Left
modeLabel.Text = "Warte auf Spieler…"
modeLabel.Parent = frame

local countLabel = Instance.new("TextLabel")
countLabel.Name = "CountLabel"
countLabel.Size = UDim2.new(1, -20, 0, 20)
countLabel.Position = UDim2.fromOffset(10, 64)
countLabel.BackgroundTransparency = 1
countLabel.Font = Enum.Font.Gotham
countLabel.TextSize = 13
countLabel.TextColor3 = Color3.fromRGB(180, 190, 210)
countLabel.TextXAlignment = Enum.TextXAlignment.Left
countLabel.Text = "Spieler: 0"
countLabel.Parent = frame

local listLabel = Instance.new("TextLabel")
listLabel.Name = "ListLabel"
listLabel.Size = UDim2.new(1, -20, 0, 60)
listLabel.Position = UDim2.fromOffset(10, 88)
listLabel.BackgroundTransparency = 1
listLabel.Font = Enum.Font.Gotham
listLabel.TextSize = 12
listLabel.TextColor3 = Color3.fromRGB(150, 160, 180)
listLabel.TextXAlignment = Enum.TextXAlignment.Left
listLabel.TextYAlignment = Enum.TextYAlignment.Top
listLabel.TextWrapped = true
listLabel.Text = ""
listLabel.Parent = frame

local leaveBtn = Instance.new("TextButton")
leaveBtn.Size = UDim2.fromOffset(140, 32)
leaveBtn.Position = UDim2.new(0.5, -70, 1, -44)
leaveBtn.BackgroundColor3 = Color3.fromRGB(80, 90, 110)
leaveBtn.Font = Enum.Font.GothamBold
leaveBtn.TextSize = 13
leaveBtn.TextColor3 = Color3.new(1, 1, 1)
leaveBtn.Text = "Warteschlange verlassen"
leaveBtn.Parent = frame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 8)
btnCorner.Parent = leaveBtn

local function hideOthers()
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then lobby.Enabled = false end
end

local function updateQueue(payload)
	hideOthers()
	gui.Enabled = true
	modeLabel.Text = payload.modeLabel or "Warte auf Spieler…"
	countLabel.Text = string.format("Spieler: %d / %d", payload.count or 0, payload.target or 1)
	if payload.players and #payload.players > 0 then
		listLabel.Text = table.concat(payload.players, "\n")
	else
		listLabel.Text = "—"
	end
end

Remotes.QueueUpdate.OnClientEvent:Connect(updateQueue)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" then
		hideOthers()
		gui.Enabled = true
	elseif state.phase == "hub" then
		gui.Enabled = false
	end
end)

Remotes.MatchState.OnClientEvent:Connect(function(payload)
	if payload.phase and payload.phase ~= "Idle" then
		gui.Enabled = false
	end
end)

leaveBtn.MouseButton1Click:Connect(function()
	gui.Enabled = false
	Remotes.LeaveQueue:FireServer()
end)
