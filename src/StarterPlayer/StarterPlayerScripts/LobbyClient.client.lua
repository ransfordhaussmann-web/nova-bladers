local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")

local queueLabel = panel:FindFirstChild("QueueLabel")
local cancelButton = panel:FindFirstChild("CancelQueueButton")
local startButton = panel:FindFirstChild("StartButton")

local function hideOthers()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then
		hud.Enabled = false
	end
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = false
	end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then
		mobile.Enabled = false
	end
end

local function applyHubOverlay()
	if panel:IsA("GuiObject") then
		panel.AnchorPoint = Vector2.new(0, 0)
		panel.Position = UDim2.fromOffset(12, 12)
		panel.Size = UDim2.fromOffset(260, 220)
	end
	if startButton then
		startButton.Text = "Queue (Fallback)"
		startButton.Size = UDim2.fromOffset(120, 28)
	end
end

local function enableWalking()
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 16
	end
end

local function updateQueueDisplay(payload)
	if not queueLabel or not cancelButton or not startButton then
		return
	end

	if payload.status == "searching" then
		queueLabel.Visible = true
		cancelButton.Visible = true
		startButton.Visible = false
		queueLabel.Text = string.format(
			"⏳ Warteschlange: %s\nSpieler: %d / %d",
			payload.modeLabel or payload.modeId,
			payload.playersInQueue or 1,
			payload.playersNeeded or 1
		)
	elseif payload.status == "matched" then
		queueLabel.Visible = true
		cancelButton.Visible = false
		startButton.Visible = false
		queueLabel.Text = string.format("✓ Match gefunden: %s", payload.modeLabel or "")
	else
		queueLabel.Visible = false
		cancelButton.Visible = false
		startButton.Visible = true
		queueLabel.Text = ""
	end
end

local function updateStats(payload)
	panel.StatsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d",
		payload.wins,
		payload.losses,
		payload.rank
	)
	panel.ModeLabel.Text = payload.modeLabel or "Modus: Training"
	if panel:FindFirstChild("LeaderboardLabel") and payload.leaderboard then
		local lines = { "🏆 Top Spieler:" }
		for _, entry in payload.leaderboard do
			table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
		end
		if #payload.leaderboard == 0 then
			table.insert(lines, "Noch keine Einträge")
		end
		panel.LeaderboardLabel.Text = table.concat(lines, "\n")
	end

	if payload.inQueue then
		updateQueueDisplay({
			status = "searching",
			modeId = payload.queuedModeId,
			modeLabel = payload.modeLabel,
			playersInQueue = 1,
			playersNeeded = payload.queuedModeId == "training" and 1
				or payload.queuedModeId == "pvp" and 2
				or 3,
		})
	else
		updateQueueDisplay({ status = "idle" })
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
		updateQueueDisplay({ status = "idle" })
	elseif state.phase == "queued" then
		gui.Enabled = true
		enableWalking()
	elseif state.phase == "match" then
		gui.Enabled = false
		updateQueueDisplay({
			status = "matched",
			modeLabel = state.modeLabel,
		})
	end
end)

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	updateQueueDisplay(payload)
end)

if startButton then
	startButton.MouseButton1Click:Connect(function()
		Remotes.JoinQueue:FireServer("training")
	end)
end

if cancelButton then
	cancelButton.MouseButton1Click:Connect(function()
		Remotes.LeaveQueue:FireServer()
	end)
end

applyHubOverlay()
