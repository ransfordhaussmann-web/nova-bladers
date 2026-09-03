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
		panel.Size = UDim2.fromOffset(260, 220)
	end
	local startButton = panel:FindFirstChild("StartButton")
	if startButton then
		startButton.Text = "Matchmaking"
		startButton.Size = UDim2.fromOffset(120, 28)
	end
	local queueLabel = panel:FindFirstChild("QueueLabel")
	if queueLabel then
		queueLabel.Text = ""
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

local function updateQueueStatus(payload)
	local queueLabel = panel:FindFirstChild("QueueLabel")
	local leaveButton = panel:FindFirstChild("LeaveQueueButton")
	local startButton = panel:FindFirstChild("StartButton")
	if not queueLabel then
		return
	end

	if payload.inQueue then
		local line = string.format("⏳ Queue: %d Spieler", payload.total or 1)
		if payload.needed and payload.needed > 0 then
			line = line .. string.format(" (noch %d)", payload.needed)
		end
		if payload.modeLabel then
			line = line .. "\nModus: " .. payload.modeLabel
		end
		if payload.waitSeconds and payload.waitSeconds > 0 then
			line = line .. string.format("\nWarte: %ds", payload.waitSeconds)
		end
		queueLabel.Text = line
		if leaveButton then
			leaveButton.Visible = true
		end
		if startButton then
			startButton.Text = "In Queue..."
			startButton.AutoButtonColor = false
		end
	else
		queueLabel.Text = ""
		if leaveButton then
			leaveButton.Visible = false
		end
		if startButton then
			startButton.Text = "Matchmaking"
			startButton.AutoButtonColor = true
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

Remotes.MatchQueueState.OnClientEvent:Connect(function(payload)
	updateQueueStatus(payload)
	if payload.inQueue then
		gui.Enabled = true
	end
end)

panel.StartButton.MouseButton1Click:Connect(function()
	Remotes.JoinMatchQueue:FireServer()
end)

local leaveButton = panel:FindFirstChild("LeaveQueueButton")
if leaveButton then
	leaveButton.MouseButton1Click:Connect(function()
		Remotes.LeaveMatchQueue:FireServer()
	end)
end

applyHubOverlay()
