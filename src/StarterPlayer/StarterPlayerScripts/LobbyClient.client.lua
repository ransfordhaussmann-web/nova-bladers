local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")
local queueLabel = panel:FindFirstChild("QueueLabel")
local cancelButton = panel:FindFirstChild("CancelQueueButton")

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
		startButton.Text = "Schnellmatch"
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

local function updateQueueUI(queueStatus)
	if not queueStatus or not queueStatus.queued then
		if queueLabel then
			queueLabel.Visible = false
			queueLabel.Text = ""
		end
		if cancelButton then
			cancelButton.Visible = false
		end
		panel.StartButton.Visible = true
		return
	end

	if queueLabel then
		queueLabel.Visible = true
		queueLabel.Text = string.format(
			"Suche Gegner…\n%s — %d/%d Spieler",
			queueStatus.modeLabel or queueStatus.mode,
			queueStatus.playersInQueue or 0,
			queueStatus.requiredPlayers or 0
		)
	end
	if cancelButton then
		cancelButton.Visible = true
	end
	panel.StartButton.Visible = false
end

local function updateStats(payload)
	panel.StatsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d",
		payload.wins, payload.losses, payload.rank
	)
	panel.ModeLabel.Text = payload.modeLabel or "Modus: Training"
	if payload.queueStatus then
		updateQueueUI(payload.queueStatus)
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
	if state.phase == "hub" or state.phase == "queued" then
		hideOthers()
		applyHubOverlay()
		gui.Enabled = true
		enableWalking()
	elseif state.phase == "arena" then
		gui.Enabled = false
	end
end)

Remotes.QueueStatus.OnClientEvent:Connect(function(queueStatus)
	updateQueueUI(queueStatus)
	if queueStatus.queued then
		panel.ModeLabel.Text = string.format(
			"Warteschlange: %s (%d/%d)",
			queueStatus.modeLabel or queueStatus.mode,
			queueStatus.playersInQueue or 0,
			queueStatus.requiredPlayers or 0
		)
	end
end)

panel.StartButton.MouseButton1Click:Connect(function()
	Remotes.EnterArena:FireServer()
end)

if cancelButton then
	cancelButton.MouseButton1Click:Connect(function()
		Remotes.QueueLeave:FireServer()
	end)
end

applyHubOverlay()
