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
frame.Size = UDim2.fromOffset(300, 130)
frame.Position = UDim2.new(0.5, -150, 0.15, 0)
frame.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
frame.BackgroundTransparency = 0.1
frame.BorderSizePixel = 0
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0, 32)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextColor3 = Color3.fromRGB(120, 180, 255)
title.Text = "Matchmaking"
title.Parent = frame

local status = Instance.new("TextLabel")
status.Name = "Status"
status.Size = UDim2.new(1, -20, 0, 48)
status.Position = UDim2.fromOffset(10, 36)
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamMedium
status.TextSize = 14
status.TextColor3 = Color3.new(1, 1, 1)
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.Text = "Suche Gegner..."
status.Parent = frame

local leaveBtn = Instance.new("TextButton")
leaveBtn.Name = "LeaveButton"
leaveBtn.Size = UDim2.fromOffset(120, 32)
leaveBtn.Position = UDim2.new(0.5, -60, 1, -42)
leaveBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
leaveBtn.Font = Enum.Font.GothamBold
leaveBtn.TextSize = 14
leaveBtn.TextColor3 = Color3.new(1, 1, 1)
leaveBtn.Text = "Abbrechen"
leaveBtn.Parent = frame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = leaveBtn

local function hideLobby()
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
end

local function showLobby()
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = true
	end
end

local function updateQueue(payload)
	if not payload.inQueue then
		gui.Enabled = false
		showLobby()
		return
	end

	hideLobby()
	gui.Enabled = true
	status.Text = string.format(
		"Spieler in Queue: %d\nModus: %s\nStart in ~%ds",
		payload.playersInQueue or 1,
		payload.mode or "Training",
		payload.waitSeconds or 0
	)
end

Remotes.QueueStatus.OnClientEvent:Connect(updateQueue)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "queue" then
		gui.Enabled = true
		hideLobby()
	elseif state.phase == "hub" then
		gui.Enabled = false
		showLobby()
	elseif state.phase == "arena" then
		gui.Enabled = false
	end
end)

leaveBtn.MouseButton1Click:Connect(function()
	Remotes.LeaveQueue:FireServer()
	Remotes.ReturnToHub:FireServer()
	gui.Enabled = false
	showLobby()
end)
