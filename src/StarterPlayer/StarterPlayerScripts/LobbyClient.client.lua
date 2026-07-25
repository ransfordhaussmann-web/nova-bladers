local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")

local recommendedMode = "training"

local function hideOthers()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then select.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local function getOrCreate(name, className, parent)
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = parent
	return created
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

	local leaveButton = getOrCreate("LeaveQueueButton", "TextButton", panel)
	leaveButton.Size = UDim2.fromOffset(120, 28)
	leaveButton.Position = UDim2.fromOffset(132, 100)
	leaveButton.BackgroundColor3 = Color3.fromRGB(90, 50, 55)
	leaveButton.Font = Enum.Font.GothamBold
	leaveButton.TextSize = 13
	leaveButton.TextColor3 = Color3.new(1, 1, 1)
	leaveButton.Text = "Verlassen"
	leaveButton.Visible = false

	local queueLabel = getOrCreate("QueueLabel", "TextLabel", panel)
	queueLabel.Size = UDim2.new(1, -16, 0, 36)
	queueLabel.Position = UDim2.fromOffset(8, 132)
	queueLabel.BackgroundTransparency = 1
	queueLabel.Font = Enum.Font.GothamMedium
	queueLabel.TextSize = 11
	queueLabel.TextColor3 = Color3.fromRGB(170, 210, 255)
	queueLabel.TextXAlignment = Enum.TextXAlignment.Left
	queueLabel.TextYAlignment = Enum.TextYAlignment.Top
	queueLabel.Text = ""

	local leaderboardLabel = panel:FindFirstChild("LeaderboardLabel")
	if leaderboardLabel then
		leaderboardLabel.Position = UDim2.fromOffset(8, 172)
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

local function updateStats(payload)
	panel.StatsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d",
		payload.wins, payload.losses, payload.rank
	)
	panel.ModeLabel.Text = payload.modeLabel or "Modus: Training"
	if payload.activeModeId then
		recommendedMode = payload.activeModeId
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

local function formatQueueSummary(queues)
	if not queues then
		return ""
	end

	local lines = {"Queues:"}
	for _, modeId in { "training", "pvp", "ffa" } do
		local snapshot = queues[modeId]
		if snapshot then
			table.insert(lines, string.format(
				"%s %d/%d",
				snapshot.modeLabel,
				snapshot.count,
				snapshot.required
			))
		end
	end
	return table.concat(lines, "\n")
end

local function updateQueue(payload)
	local queueLabel = panel:FindFirstChild("QueueLabel")
	local startButton = panel:FindFirstChild("StartButton")
	local leaveButton = panel:FindFirstChild("LeaveQueueButton")

	if payload.inQueue then
		if queueLabel then
			queueLabel.Text = string.format(
				"⏳ %s — %d/%d Spieler\nPosition: %d",
				payload.modeLabel or payload.mode,
				payload.waiting or 0,
				payload.required or 0,
				payload.position or 1
			)
		end
		if startButton then
			startButton.Text = "Wartet..."
			startButton.AutoButtonColor = false
		end
		if leaveButton then
			leaveButton.Visible = true
		end
	else
		if queueLabel then
			queueLabel.Text = formatQueueSummary(payload.queues)
		end
		if startButton then
			startButton.Text = "Warteschlange"
			startButton.AutoButtonColor = true
		end
		if leaveButton then
			leaveButton.Visible = false
		end
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
	end
end)

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	updateQueue(payload)
end)

panel.StartButton.MouseButton1Click:Connect(function()
	Remotes.JoinQueue:FireServer(recommendedMode)
end)

local leaveButton = panel:FindFirstChild("LeaveQueueButton")
if leaveButton then
	leaveButton.MouseButton1Click:Connect(function()
		Remotes.LeaveQueue:FireServer()
	end)
end

applyHubOverlay()
