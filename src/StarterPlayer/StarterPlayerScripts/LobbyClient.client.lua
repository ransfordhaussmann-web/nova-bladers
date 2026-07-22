local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")

local startButton = panel:WaitForChild("StartButton")
local queueStatus = panel:FindFirstChild("QueueStatusLabel")
local leaveQueueButton = panel:FindFirstChild("LeaveQueueButton")

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
		panel.Size = UDim2.fromOffset(260, 180)
	end
	startButton.Text = "Warteschlange"
	startButton.Size = UDim2.fromOffset(120, 28)
	startButton.Visible = true
	if queueStatus then
		queueStatus.Visible = false
	end
	if leaveQueueButton then
		leaveQueueButton.Visible = false
	end
end

local function applyQueueOverlay(payload)
	if panel:IsA("GuiObject") then
		panel.Size = UDim2.fromOffset(280, 200)
	end
	startButton.Visible = false
	if queueStatus then
		queueStatus.Visible = true
		local playerLine = table.concat(payload.players or {}, ", ")
		queueStatus.Text = string.format(
			"⏳ Warteschlange\nModus: %s\nSpieler: %d\nStart in ~%ds\n%s",
			payload.modeLabel or payload.mode or "?",
			payload.count or 0,
			payload.remainingSec or 0,
			playerLine
		)
	end
	if leaveQueueButton then
		leaveQueueButton.Visible = true
	end
	panel.ModeLabel.Text = "In Warteschlange..."
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
	elseif state.phase == "queue" then
		gui.Enabled = true
	elseif state.phase == "arena" then
		gui.Enabled = false
	end
end)

Remotes.QueueState.OnClientEvent:Connect(function(payload)
	if payload.inQueue then
		hideOthers()
		applyQueueOverlay(payload)
		gui.Enabled = true
	end
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	applyHubOverlay()
	enableWalking()
end)

startButton.MouseButton1Click:Connect(function()
	Remotes.EnterArena:FireServer()
end)

if leaveQueueButton then
	leaveQueueButton.MouseButton1Click:Connect(function()
		Remotes.LeaveQueue:FireServer()
	end)
end

applyHubOverlay()
