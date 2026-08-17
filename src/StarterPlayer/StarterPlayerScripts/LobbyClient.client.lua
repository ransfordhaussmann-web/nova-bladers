local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")

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
		panel.Size = UDim2.fromOffset(280, 220)
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

local function getOrCreate(name, className)
	local existing = panel:FindFirstChild(name)
	if existing then
		return existing
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = panel
	return inst
end

local queueLabel = getOrCreate("QueueLabel", "TextLabel")
queueLabel.Size = UDim2.new(1, -16, 0, 36)
queueLabel.Position = UDim2.fromOffset(8, 132)
queueLabel.BackgroundTransparency = 1
queueLabel.Font = Enum.Font.GothamMedium
queueLabel.TextSize = 11
queueLabel.TextColor3 = Color3.fromRGB(160, 210, 255)
queueLabel.TextXAlignment = Enum.TextXAlignment.Left
queueLabel.TextYAlignment = Enum.TextYAlignment.Top
queueLabel.TextWrapped = true
queueLabel.Text = ""
queueLabel.Visible = false

local leaveQueueBtn = getOrCreate("LeaveQueueButton", "TextButton")
leaveQueueBtn.Size = UDim2.fromOffset(120, 24)
leaveQueueBtn.Position = UDim2.fromOffset(136, 100)
leaveQueueBtn.BackgroundColor3 = Color3.fromRGB(80, 50, 55)
leaveQueueBtn.Font = Enum.Font.GothamBold
leaveQueueBtn.TextSize = 12
leaveQueueBtn.TextColor3 = Color3.new(1, 1, 1)
leaveQueueBtn.Text = "Abbrechen"
leaveQueueBtn.Visible = false
if not leaveQueueBtn:FindFirstChildOfClass("UICorner") then
	local leaveCorner = Instance.new("UICorner")
	leaveCorner.CornerRadius = UDim.new(0, 6)
	leaveCorner.Parent = leaveQueueBtn
end

local function updateStats(payload)
	panel.StatsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d",
		payload.wins, payload.losses, payload.rank
	)
	panel.ModeLabel.Text = payload.modeLabel or "Modus: Training"
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

local function updateQueue(payload)
	if not payload or not payload.inQueue then
		queueLabel.Visible = false
		leaveQueueBtn.Visible = false
		if panel:FindFirstChild("StartButton") then
			panel.StartButton.Visible = true
		end
		return
	end

	queueLabel.Visible = true
	leaveQueueBtn.Visible = true
	if panel:FindFirstChild("StartButton") then
		panel.StartButton.Visible = false
	end

	local lines = {
		string.format("In Warteschlange — %s", payload.modeLabel or "Training"),
		string.format("%d Spieler warten", payload.waiting or 0),
	}
	if payload.players and #payload.players > 0 then
		table.insert(lines, table.concat(payload.players, ", "))
	end
	if payload.countdown and payload.countdown > 0 then
		table.insert(lines, string.format("Start in %ds…", payload.countdown))
	end
	queueLabel.Text = table.concat(lines, "\n")
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	hideOthers()
	applyHubOverlay()
	updateStats(payload)
	gui.Enabled = true
	enableWalking()
end)

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	updateQueue(payload)
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		hideOthers()
		applyHubOverlay()
		gui.Enabled = true
		enableWalking()
		updateQueue({ inQueue = false })
	elseif state.phase == "queued" then
		gui.Enabled = true
		updateQueue({ inQueue = true, waiting = 1, modeLabel = state.modeLabel or "Training" })
	elseif state.phase == "arena" then
		gui.Enabled = false
		updateQueue({ inQueue = false })
	end
end)

panel.StartButton.MouseButton1Click:Connect(function()
	Remotes.EnterArena:FireServer()
end)

leaveQueueBtn.MouseButton1Click:Connect(function()
	Remotes.LeaveQueue:FireServer()
end)

applyHubOverlay()
