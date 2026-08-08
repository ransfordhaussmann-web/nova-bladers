local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")

local queueLabel = panel:FindFirstChild("QueueLabel")
local leaveQueueBtn = panel:FindFirstChild("LeaveQueueButton")
local activeModeId = "training"

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
		startButton.Text = "Warteschlange (Auto)"
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

local function formatQueueStatus(snapshot)
	if not snapshot or not snapshot.inQueue or not snapshot.modeId then
		return nil
	end
	local info = snapshot.queues and snapshot.queues[snapshot.modeId]
	if not info then
		return "In Warteschlange..."
	end
	return string.format(
		"⏳ %s: %d/%d Spieler",
		info.label,
		info.count,
		info.minPlayers
	)
end

local function updateQueueUI(snapshot)
	if not queueLabel or not leaveQueueBtn then
		return
	end
	local text = formatQueueStatus(snapshot)
	if text then
		queueLabel.Text = text
		queueLabel.Visible = true
		leaveQueueBtn.Visible = true
	else
		queueLabel.Text = ""
		queueLabel.Visible = false
		leaveQueueBtn.Visible = false
	end
end

local function updateStats(payload)
	panel.StatsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d",
		payload.wins, payload.losses, payload.rank
	)
	panel.ModeLabel.Text = payload.modeLabel or "Modus: Training"
	if payload.activeModeId then
		activeModeId = payload.activeModeId
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
	if payload.queue then
		updateQueueUI(payload.queue)
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	hideOthers()
	applyHubOverlay()
	updateStats(payload)
	gui.Enabled = true
	enableWalking()
end)

Remotes.QueueUpdate.OnClientEvent:Connect(function(snapshot)
	updateQueueUI(snapshot)
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		hideOthers()
		applyHubOverlay()
		gui.Enabled = true
		enableWalking()
	elseif state.phase == "arena" then
		gui.Enabled = false
		updateQueueUI(nil)
	end
end)

panel.StartButton.MouseButton1Click:Connect(function()
	Remotes.QueueJoin:FireServer(activeModeId)
end)

if leaveQueueBtn then
	leaveQueueBtn.MouseButton1Click:Connect(function()
		Remotes.QueueLeave:FireServer()
	end)
end

applyHubOverlay()
