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
		panel.Size = UDim2.fromOffset(260, 210)
	end
	local startButton = panel:FindFirstChild("StartButton")
	if startButton then
		startButton.Text = "Queue (Auto)"
		startButton.Size = UDim2.fromOffset(120, 28)
	end
	local leaveButton = panel:FindFirstChild("LeaveQueueButton")
	if leaveButton then
		leaveButton.Visible = false
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
	if panel:FindFirstChild("QueueLabel") and payload.queues then
		local queueLines = {"Matchmaking:"}
		for _, info in payload.queues do
			table.insert(queueLines, string.format("%s: %d/%d", info.label, info.count, info.required))
		end
		panel.QueueLabel.Text = table.concat(queueLines, "\n")
	end
end

local function updateQueueStatus(payload)
	local queueLabel = panel:FindFirstChild("QueueLabel")
	local leaveButton = panel:FindFirstChild("LeaveQueueButton")
	local startButton = panel:FindFirstChild("StartButton")

	if payload.queues and queueLabel then
		local queueLines = {"Matchmaking:"}
		for _, info in payload.queues do
			table.insert(queueLines, string.format("%s: %d/%d", info.label, info.count, info.required))
		end
		panel.QueueLabel.Text = table.concat(queueLines, "\n")
	end

	if payload.queued then
		if queueLabel then
			local modeLabel = payload.modeLabel or payload.modeId or "Queue"
			queueLabel.Text = string.format(
				"⏳ In Queue: %s (%d/%d)",
				modeLabel,
				payload.count or 0,
				payload.required or 0
			)
		end
		if leaveButton then
			leaveButton.Visible = true
		end
		if startButton then
			startButton.Visible = false
		end
	else
		if leaveButton then
			leaveButton.Visible = false
		end
		if startButton then
			startButton.Visible = true
		end
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	hideOthers()
	applyHubOverlay()
	updateStats(payload)
	updateQueueStatus(payload)
	gui.Enabled = true
	enableWalking()
end)

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	updateQueueStatus(payload)
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

panel.StartButton.MouseButton1Click:Connect(function()
	Remotes.EnterArena:FireServer()
end)

local leaveQueueButton = panel:FindFirstChild("LeaveQueueButton")
if leaveQueueButton then
	leaveQueueButton.MouseButton1Click:Connect(function()
		Remotes.QueueLeave:FireServer()
	end)
end

applyHubOverlay()
