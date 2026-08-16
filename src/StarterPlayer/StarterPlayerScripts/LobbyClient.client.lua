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
		startButton.Text = "Queue (Auto)"
		startButton.Size = UDim2.fromOffset(120, 28)
	end
end

local function updateQueue(payload)
	local queueLabel = panel:FindFirstChild("QueueLabel")
	local leaveBtn = panel:FindFirstChild("LeaveQueueButton")
	if not queueLabel then
		return
	end

	if payload.queuedMode then
		queueLabel.Text = string.format(
			"⏳ Queue: %s (%d/%d)",
			payload.queuedLabel or payload.queuedMode,
			payload.queuedCount or 0,
			payload.queuedMin or 1
		)
		queueLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
		if leaveBtn then
			leaveBtn.Visible = true
		end
	else
		local lines = {}
		if payload.queues then
			for _, modeId in { "training", "pvp", "ffa" } do
				local info = payload.queues[modeId]
				if info then
					table.insert(lines, string.format("%s: %d/%d", info.label, info.count, info.min))
				end
			end
		end
		queueLabel.Text = table.concat(lines, "  ·  ")
		queueLabel.TextColor3 = Color3.fromRGB(140, 160, 190)
		if leaveBtn then
			leaveBtn.Visible = false
		end
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

Remotes.QueueState.OnClientEvent:Connect(function(payload)
	updateQueue(payload)
end)

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

panel.StartButton.MouseButton1Click:Connect(function()
	Remotes.EnterArena:FireServer()
end)

local leaveBtn = panel:FindFirstChild("LeaveQueueButton")
if leaveBtn then
	leaveBtn.MouseButton1Click:Connect(function()
		Remotes.LeaveQueue:FireServer()
	end)
end

applyHubOverlay()
