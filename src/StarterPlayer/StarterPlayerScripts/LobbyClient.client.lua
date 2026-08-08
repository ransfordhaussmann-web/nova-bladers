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

local function updateQueueUI(payload)
	local queueLabel = panel:FindFirstChild("QueueLabel")
	local leaveBtn = panel:FindFirstChild("LeaveQueueButton")
	local startBtn = panel:FindFirstChild("StartButton")

	if not queueLabel or not leaveBtn or not startBtn then
		return
	end

	if payload.inQueue then
		queueLabel.Visible = true
		leaveBtn.Visible = true
		startBtn.Visible = false

		local lines = { ("In Warteschlange (%d Spieler)"):format(payload.count or 1) }
		if payload.modeLabel then
			table.insert(lines, payload.modeLabel)
		end
		if payload.gatherDelay and payload.gatherDelay > 0 then
			table.insert(lines, ("Match startet in %ds…"):format(payload.gatherDelay))
		elseif payload.soloWait and payload.soloWait > 0 then
			table.insert(lines, ("Solo-Training in %ds…"):format(payload.soloWait))
		end
		queueLabel.Text = table.concat(lines, "\n")
	else
		queueLabel.Visible = false
		leaveBtn.Visible = false
		startBtn.Visible = true
		queueLabel.Text = ""
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
		updateQueueUI({ inQueue = false })
	elseif state.phase == "arena" then
		gui.Enabled = false
	end
end)

Remotes.QueueStatus.OnClientEvent:Connect(function(payload)
	if payload.modeLabel and payload.inQueue then
		panel.ModeLabel.Text = payload.modeLabel
	end
	updateQueueUI(payload)
end)

panel.StartButton.MouseButton1Click:Connect(function()
	Remotes.QueueJoin:FireServer()
end)

local leaveBtn = panel:FindFirstChild("LeaveQueueButton")
if leaveBtn then
	leaveBtn.MouseButton1Click:Connect(function()
		Remotes.QueueLeave:FireServer()
	end)
end

applyHubOverlay()
