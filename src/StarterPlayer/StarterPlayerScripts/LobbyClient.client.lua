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
		startButton.Text = "Schnellsuche"
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

local function updateQueueDisplay(payload)
	local queueLabel = panel:FindFirstChild("QueueLabel")
	local leaveButton = panel:FindFirstChild("LeaveQueueButton")
	if not queueLabel or not leaveButton then
		return
	end

	if payload.inQueue then
		queueLabel.Visible = true
		leaveButton.Visible = true
		queueLabel.Text = string.format(
			"Warteschlange: %s\nPlatz %d von %d (min. %d)",
			payload.modeLabel or payload.modeId,
			payload.position or 1,
			payload.total or 1,
			payload.needed or 1
		)
	else
		queueLabel.Visible = false
		leaveButton.Visible = false
		queueLabel.Text = ""
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
	if payload.queuedModeId then
		updateQueueDisplay({
			inQueue = true,
			modeId = payload.queuedModeId,
			modeLabel = payload.queuedModeId == "ffa" and "FFA"
				or payload.queuedModeId == "pvp" and "1v1 PvP"
				or "Training",
			position = 1,
			total = 1,
			needed = payload.queuedModeId == "ffa" and 3
				or payload.queuedModeId == "pvp" and 2
				or 1,
		})
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	hideOthers()
	applyHubOverlay()
	updateStats(payload)
	gui.Enabled = true
	enableWalking()
end)

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	updateQueueDisplay(payload)
	if payload.inQueue then
		gui.Enabled = true
		enableWalking()
	end
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" or state.phase == "queued" then
		hideOthers()
		applyHubOverlay()
		gui.Enabled = true
		enableWalking()
		if state.phase == "queued" and state.modeId then
			panel.ModeLabel.Text = "Modus: " .. (state.modeLabel or state.modeId)
		end
	elseif state.phase == "arena" then
		gui.Enabled = false
	end
end)

panel.StartButton.MouseButton1Click:Connect(function()
	Remotes.EnterArena:FireServer()
end)

local leaveButton = panel:FindFirstChild("LeaveQueueButton")
if leaveButton then
	leaveButton.MouseButton1Click:Connect(function()
		Remotes.LeaveQueue:FireServer()
	end)
end

applyHubOverlay()
