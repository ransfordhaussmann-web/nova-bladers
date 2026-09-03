local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")
local startButton = panel:WaitForChild("StartButton")

local function getQueueLabel()
	return panel:FindFirstChild("QueueLabel")
end

local function getLeaveQueueButton()
	return panel:FindFirstChild("LeaveQueueButton")
end

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
	startButton.Text = "Warteschlange"
	startButton.Size = UDim2.fromOffset(120, 28)
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
	local queueLabel = getQueueLabel()
	local leaveBtn = getLeaveQueueButton()
	if not queueLabel or not leaveBtn then
		return
	end

	if payload.inQueue then
		queueLabel.Visible = true
		queueLabel.Text = payload.statusText or "In Warteschlange..."
		leaveBtn.Visible = true
		startButton.Visible = false
	else
		queueLabel.Visible = false
		queueLabel.Text = ""
		leaveBtn.Visible = false
		startButton.Visible = true
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	hideOthers()
	applyHubOverlay()
	updateStats(payload)
	updateQueueUI({
		inQueue = payload.inQueue,
		statusText = payload.inQueue and "In Warteschlange..." or nil,
	})
	gui.Enabled = true
	enableWalking()
end)

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	updateQueueUI(payload)
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		hideOthers()
		applyHubOverlay()
		gui.Enabled = true
		enableWalking()
	elseif state.phase == "match" then
		gui.Enabled = false
	end
end)

startButton.MouseButton1Click:Connect(function()
	Remotes.EnterArena:FireServer()
end)

local leaveQueueBtn = getLeaveQueueButton()
if leaveQueueBtn then
	leaveQueueBtn.MouseButton1Click:Connect(function()
		Remotes.QueueLeave:FireServer()
	end)
end

applyHubOverlay()
