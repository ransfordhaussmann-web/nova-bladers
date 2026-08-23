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
		panel.Size = UDim2.fromOffset(260, 200)
	end
	local startButton = panel:FindFirstChild("StartButton")
	if startButton then
		startButton.Text = "Queue beitreten"
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

local function formatQueueCounts(counts)
	if not counts then
		return ""
	end
	return string.format(
		"Queue: Training %d | PvP %d | FFA %d",
		counts.training or 0,
		counts.pvp or 0,
		counts.ffa or 0
	)
end

local function updateQueueUI(payload)
	local startButton = panel:FindFirstChild("StartButton")
	local queueLabel = panel:FindFirstChild("QueueLabel")
	local leaveButton = panel:FindFirstChild("LeaveQueueButton")

	if payload.matchFound then
		if queueLabel then
			queueLabel.Visible = true
			queueLabel.Text = string.format("Match gefunden! (%s)", payload.modeLabel or "")
		end
		if startButton then startButton.Visible = false end
		if leaveButton then leaveButton.Visible = false end
		return
	end

	if payload.inQueue then
		if startButton then startButton.Visible = false end
		if leaveButton then leaveButton.Visible = true end
		if queueLabel then
			queueLabel.Visible = true
			local waitHint = ""
			if payload.modeId == "training" then
				waitHint = " (Solo nach kurzer Wartezeit)"
			elseif payload.modeId == "pvp" then
				waitHint = " (Warte auf Gegner)"
			elseif payload.modeId == "ffa" then
				waitHint = " (Mind. 3 Spieler)"
			end
			queueLabel.Text = string.format(
				"In Queue: %s%s\n%s",
				payload.modeLabel or payload.modeId or "?",
				waitHint,
				formatQueueCounts(payload.counts)
			)
		end
	else
		if startButton then startButton.Visible = true end
		if leaveButton then leaveButton.Visible = false end
		if queueLabel then
			queueLabel.Visible = false
			queueLabel.Text = ""
		end
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

Remotes.MatchmakingUpdate.OnClientEvent:Connect(function(payload)
	if payload.inQueue or payload.matchFound then
		gui.Enabled = true
	end
	updateQueueUI(payload)
end)

local startButton = panel:FindFirstChild("StartButton")
if startButton then
	startButton.MouseButton1Click:Connect(function()
		Remotes.MatchmakingJoin:FireServer()
	end)
end

local leaveButton = panel:FindFirstChild("LeaveQueueButton")
if leaveButton then
	leaveButton.MouseButton1Click:Connect(function()
		Remotes.MatchmakingLeave:FireServer()
	end)
end

applyHubOverlay()
