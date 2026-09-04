local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")

local activeModeId = "training"

local queueLabel = panel:FindFirstChild("QueueLabel")
if not queueLabel then
	queueLabel = Instance.new("TextLabel")
	queueLabel.Name = "QueueLabel"
	queueLabel.Size = UDim2.new(1, -16, 0, 36)
	queueLabel.Position = UDim2.fromOffset(8, 148)
	queueLabel.BackgroundTransparency = 1
	queueLabel.Font = Enum.Font.GothamMedium
	queueLabel.TextSize = 13
	queueLabel.TextColor3 = Color3.fromRGB(140, 200, 255)
	queueLabel.TextWrapped = true
	queueLabel.Text = ""
	queueLabel.Visible = false
	queueLabel.Parent = panel
end

local leaveQueueButton = panel:FindFirstChild("LeaveQueueButton")
if not leaveQueueButton then
	leaveQueueButton = Instance.new("TextButton")
	leaveQueueButton.Name = "LeaveQueueButton"
	leaveQueueButton.Size = UDim2.fromOffset(120, 28)
	leaveQueueButton.Position = UDim2.fromOffset(8, 188)
	leaveQueueButton.BackgroundColor3 = Color3.fromRGB(70, 40, 45)
	leaveQueueButton.Font = Enum.Font.GothamBold
	leaveQueueButton.TextSize = 13
	leaveQueueButton.TextColor3 = Color3.new(1, 1, 1)
	leaveQueueButton.Text = "Queue verlassen"
	leaveQueueButton.Visible = false
	leaveQueueButton.Parent = panel

	local leaveCorner = Instance.new("UICorner")
	leaveCorner.CornerRadius = UDim.new(0, 6)
	leaveCorner.Parent = leaveQueueButton
end

local function hideOthers()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then select.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local function applyHubOverlay()
	if panel:IsA("GuiObject") then
		panel.AnchorPoint = Vector2.new(0, 0)
		panel.Position = UDim2.fromOffset(12, 12)
		panel.Size = UDim2.fromOffset(260, 220)
	end
	local startButton = panel:FindFirstChild("StartButton")
	if startButton then
		startButton.Text = "Warteschlange"
		startButton.Size = UDim2.fromOffset(120, 28)
	end
end

local function enableWalking()
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 16
	end
end

local function updateQueueUI(status)
	if status.inQueue then
		queueLabel.Visible = true
		leaveQueueButton.Visible = true
		queueLabel.Text = string.format(
			"⏳ %s\n%d / %d Spieler",
			status.modeLabel or status.mode,
			status.count or 0,
			status.required or 1
		)
	else
		queueLabel.Visible = false
		leaveQueueButton.Visible = false
		queueLabel.Text = ""
	end
end

local function updateStats(payload)
	panel.StatsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d",
		payload.wins, payload.losses, payload.rank
	)
	panel.ModeLabel.Text = payload.modeLabel or "Modus: Training"
	if payload.activeModeId then
		activeModeId = payload.activeModeId
	end
	if panel:FindFirstChild("LeaderboardLabel") and payload.leaderboard then
		local lines = {"🏆 Top Spieler:"}
		for _, entry in payload.leaderboard do
			table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
		end
		if #payload.leaderboard == 0 then
			table.insert(lines, "Noch keine Einträge")
		end
		panel.LeaderboardLabel.Text = table.concat(lines, "\n")
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	hideOthers()
	applyHubOverlay()
	updateStats(payload)
	gui.Enabled = true
	enableWalking()
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		hideOthers()
		applyHubOverlay()
		gui.Enabled = true
		enableWalking()
	elseif state.phase == "arena" then
		gui.Enabled = false
		updateQueueUI({ inQueue = false })
	end
end)

Remotes.QueueUpdate.OnClientEvent:Connect(function(status)
	updateQueueUI(status)
end)

panel.StartButton.MouseButton1Click:Connect(function()
	Remotes.JoinQueue:FireServer(activeModeId)
end)

leaveQueueButton.MouseButton1Click:Connect(function()
	Remotes.LeaveQueue:FireServer()
end)

applyHubOverlay()
