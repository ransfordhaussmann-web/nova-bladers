local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")

local preferredMode = "training"
local inQueue = false

local function hideOthers()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then select.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local function ensureQueueLabel()
	local label = panel:FindFirstChild("QueueLabel")
	if not label then
		label = Instance.new("TextLabel")
		label.Name = "QueueLabel"
		label.Size = UDim2.new(1, -16, 0, 36)
		label.Position = UDim2.fromOffset(8, 124)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamMedium
		label.TextSize = 12
		label.TextColor3 = Color3.fromRGB(180, 200, 230)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.TextWrapped = true
		label.Text = ""
		label.Parent = panel
	end
	return label
end

local function ensureQueueButtons()
	local joinBtn = panel:FindFirstChild("QueueButton")
	if not joinBtn then
		joinBtn = Instance.new("TextButton")
		joinBtn.Name = "QueueButton"
		joinBtn.Size = UDim2.fromOffset(120, 28)
		joinBtn.Position = UDim2.fromOffset(8, 100)
		joinBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 255)
		joinBtn.Font = Enum.Font.GothamBold
		joinBtn.TextSize = 13
		joinBtn.TextColor3 = Color3.new(1, 1, 1)
		joinBtn.Text = "In Warteschlange"
		joinBtn.Parent = panel

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = joinBtn
	end

	local leaveBtn = panel:FindFirstChild("LeaveQueueButton")
	if not leaveBtn then
		leaveBtn = Instance.new("TextButton")
		leaveBtn.Name = "LeaveQueueButton"
		leaveBtn.Size = UDim2.fromOffset(120, 28)
		leaveBtn.Position = UDim2.fromOffset(136, 100)
		leaveBtn.BackgroundColor3 = Color3.fromRGB(90, 50, 55)
		leaveBtn.Font = Enum.Font.GothamBold
		leaveBtn.TextSize = 13
		leaveBtn.TextColor3 = Color3.new(1, 1, 1)
		leaveBtn.Text = "Verlassen"
		leaveBtn.Visible = false
		leaveBtn.Parent = panel

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = leaveBtn
	end

	return joinBtn, leaveBtn
end

local function applyHubOverlay()
	if panel:IsA("GuiObject") then
		panel.AnchorPoint = Vector2.new(0, 0)
		panel.Position = UDim2.fromOffset(12, 12)
		panel.Size = UDim2.fromOffset(260, 220)
	end

	local startButton = panel:FindFirstChild("StartButton")
	if startButton then
		startButton.Visible = false
	end

	ensureQueueLabel()
	ensureQueueButtons()
end

local function modeLabelFor(id)
	if id == "pvp" then
		return "1v1 PvP"
	elseif id == "ffa" then
		return "FFA"
	end
	return "Training"
end

local function updateQueueUI(status)
	local queueLabel = ensureQueueLabel()
	local joinBtn, leaveBtn = ensureQueueButtons()

	inQueue = status.inQueue == true
	joinBtn.Visible = not inQueue
	leaveBtn.Visible = inQueue

	if inQueue then
		queueLabel.Text = string.format(
			"⏳ %s\nWartend: %d / %d",
			status.label or modeLabelFor(status.mode),
			status.waiting or 0,
			status.needed or 0
		)
	else
		queueLabel.Text = string.format("Modus: %s\nTritt der Warteschlange bei", modeLabelFor(preferredMode))
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
	if payload.preferredModeId then
		preferredMode = payload.preferredModeId
	end
	panel.ModeLabel.Text = string.format("Modus: %s", modeLabelFor(preferredMode))
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
	updateQueueUI({ inQueue = inQueue, mode = preferredMode, waiting = 0, needed = 0, label = modeLabelFor(preferredMode) })
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
		if not inQueue then
			updateQueueUI({ inQueue = false, mode = preferredMode })
		end
	elseif state.phase == "arena" then
		gui.Enabled = false
	end
end)

Remotes.QueueUpdate.OnClientEvent:Connect(function(status)
	if status.mode then
		preferredMode = status.mode
	end
	updateQueueUI(status)
end)

local joinBtn, leaveBtn = ensureQueueButtons()

joinBtn.MouseButton1Click:Connect(function()
	Remotes.JoinQueue:FireServer(preferredMode)
end)

leaveBtn.MouseButton1Click:Connect(function()
	Remotes.LeaveQueue:FireServer()
end)

applyHubOverlay()
