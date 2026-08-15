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
		startButton.Text = "Arena Queue"
		startButton.Size = UDim2.fromOffset(120, 28)
	end
end

local function setQueueUI(payload)
	local queueLabel = panel:FindFirstChild("QueueLabel")
	local leaveBtn = panel:FindFirstChild("LeaveQueueButton")
	local startButton = panel:FindFirstChild("StartButton")
	if not queueLabel or not leaveBtn then
		return
	end

	if payload.inQueue then
		queueLabel.Visible = true
		leaveBtn.Visible = true
		if startButton then
			startButton.Visible = false
		end
		queueLabel.Text = string.format(
			"⏳ Queue: %d/%d (%s)\nWarte: %ds",
			payload.count or 1,
			payload.required or 1,
			payload.modeLabel or "Training",
			payload.waitSeconds or 0
		)
	else
		queueLabel.Visible = false
		leaveBtn.Visible = false
		if startButton then
			startButton.Visible = true
		end
		queueLabel.Text = ""
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
	if payload.preferredModeId then
		panel.ModeLabel.Text ..= string.format("  · Pad: %s", payload.preferredModeId)
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
	if state.phase == "hub" then
		hideOthers()
		applyHubOverlay()
		gui.Enabled = true
		enableWalking()
		setQueueUI({ inQueue = false })
	elseif state.phase == "queue" then
		hideOthers()
		applyHubOverlay()
		gui.Enabled = true
		enableWalking()
	elseif state.phase == "arena" then
		gui.Enabled = false
		setQueueUI({ inQueue = false })
	end
end)

Remotes.QueueState.OnClientEvent:Connect(function(payload)
	setQueueUI(payload)
	if payload.inQueue then
		gui.Enabled = true
	end
end)

panel.StartButton.MouseButton1Click:Connect(function()
	Remotes.QueueJoin:FireServer()
end)

local leaveQueueBtn = panel:FindFirstChild("LeaveQueueButton")
if leaveQueueBtn then
	leaveQueueBtn.MouseButton1Click:Connect(function()
		Remotes.QueueLeave:FireServer()
	end)
end

applyHubOverlay()
