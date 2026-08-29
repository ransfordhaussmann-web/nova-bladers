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
		panel.Size = UDim2.fromOffset(280, 200)
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

local function updateQueueUI(payload)
	local queueLabel = panel:FindFirstChild("QueueLabel")
	local leaveButton = panel:FindFirstChild("LeaveQueueButton")
	local startButton = panel:FindFirstChild("StartButton")

	if not queueLabel or not leaveButton or not startButton then
		return
	end

	if payload.inQueue then
		queueLabel.Visible = true
		leaveButton.Visible = true
		startButton.Visible = false
		queueLabel.Text = string.format(
			"⏳ %s\n%d / %d Spieler",
			payload.modeLabel or "Warteschlange",
			payload.playersInQueue or 0,
			payload.playersNeeded or 0
		)
	else
		queueLabel.Visible = false
		leaveButton.Visible = false
		startButton.Visible = true
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

	if payload.queueState then
		updateQueueUI(payload.queueState)
	else
		updateQueueUI({ inQueue = false })
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
		updateQueueUI({ inQueue = false })
	end
end)

Remotes.QueueState.OnClientEvent:Connect(function(payload)
	updateQueueUI(payload)
end)

panel.StartButton.MouseButton1Click:Connect(function()
	Remotes.EnterArena:FireServer()
end)

local leaveQueueButton = panel:FindFirstChild("LeaveQueueButton")
if leaveQueueButton then
	leaveQueueButton.MouseButton1Click:Connect(function()
		Remotes.LeaveQueue:FireServer()
	end)
end

applyHubOverlay()
