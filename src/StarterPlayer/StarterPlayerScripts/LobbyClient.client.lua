local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")

local queueLabel = panel:FindFirstChild("QueueLabel")
local leaveQueueBtn = panel:FindFirstChild("LeaveQueueButton")

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
		startButton.Text = "Queue (Fallback)"
		startButton.Size = UDim2.fromOffset(120, 28)
	end
	if leaveQueueBtn then
		leaveQueueBtn.Visible = false
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

local function updateQueueUI(payload)
	if not queueLabel then
		return
	end

	local inQueue = payload.inQueue == true
	if leaveQueueBtn then
		leaveQueueBtn.Visible = inQueue
	end

	if not inQueue then
		queueLabel.Visible = false
		queueLabel.Text = ""
		return
	end

	queueLabel.Visible = true
	local modeLabel = payload.modeLabel or payload.queueMode or "Match"
	local count = payload.count or 0
	local needed = payload.needed or 1
	local maxPlayers = payload.maxPlayers or needed
	local gathering = payload.gathering == true

	if gathering then
		queueLabel.Text = string.format(
			"⏳ Queue: %s\nSpieler: %d/%d (Gathering...)",
			modeLabel, count, maxPlayers
		)
	elseif count >= needed then
		queueLabel.Text = string.format(
			"✓ Queue: %s\nStartet gleich... (%d/%d)",
			modeLabel, count, maxPlayers
		)
	else
		queueLabel.Text = string.format(
			"⏳ Queue: %s\nWarte: %d/%d Spieler",
			modeLabel, count, needed
		)
	end
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
	updateQueueUI(payload)
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	hideOthers()
	applyHubOverlay()
	updateStats(payload)
	gui.Enabled = true
	enableWalking()
end)

Remotes.QueueState.OnClientEvent:Connect(function(payload)
	updateQueueUI(payload)
	if payload.modeLabel then
		panel.ModeLabel.Text = "Modus: " .. payload.modeLabel
	end
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		hideOthers()
		applyHubOverlay()
		gui.Enabled = true
		enableWalking()
	elseif state.phase == "arena" then
		gui.Enabled = false
		if queueLabel then
			queueLabel.Visible = false
		end
		if leaveQueueBtn then
			leaveQueueBtn.Visible = false
		end
	end
end)

panel.StartButton.MouseButton1Click:Connect(function()
	Remotes.QueueJoin:FireServer()
end)

if leaveQueueBtn then
	leaveQueueBtn.MouseButton1Click:Connect(function()
		Remotes.QueueLeave:FireServer()
	end)
end

applyHubOverlay()
