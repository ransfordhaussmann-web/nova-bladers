local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")
local startButton = panel:WaitForChild("StartButton")
local queueLabel = panel:FindFirstChild("QueueLabel")
local cancelButton = panel:FindFirstChild("CancelQueueButton")

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
	if startButton then
		startButton.Text = "Quick Queue"
		startButton.Size = UDim2.fromOffset(120, 28)
		startButton.Visible = true
	end
	if cancelButton then
		cancelButton.Visible = false
	end
	if queueLabel then
		queueLabel.Visible = false
		queueLabel.Text = ""
	end
end

local function showQueueStatus(payload)
	if not queueLabel then
		return
	end
	local names = payload.playerNames or {}
	local nameLine = #names > 0 and table.concat(names, ", ") or "Warte auf Spieler..."
	queueLabel.Text = string.format(
		"Queue: %s\n%d/%d Spieler (%ds)\n%s",
		payload.modeLabel or payload.mode or "?",
		payload.playersInQueue or 0,
		payload.requiredPlayers or 1,
		payload.waitingSeconds or 0,
		nameLine
	)
	queueLabel.Visible = true
	if startButton then
		startButton.Visible = false
	end
	if cancelButton then
		cancelButton.Visible = true
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

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	hideOthers()
	applyHubOverlay()
	updateStats(payload)
	gui.Enabled = true
	enableWalking()
end)

Remotes.QueueState.OnClientEvent:Connect(function(payload)
	showQueueStatus(payload)
	gui.Enabled = true
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		hideOthers()
		applyHubOverlay()
		gui.Enabled = true
		enableWalking()
	elseif state.phase == "queue" then
		hideOthers()
		gui.Enabled = true
		enableWalking()
		if state.queue then
			showQueueStatus(state.queue)
		else
			showQueueStatus({
				mode = state.mode,
				modeLabel = state.modeLabel,
				playersInQueue = 1,
				requiredPlayers = state.mode == "pvp" and 2 or (state.mode == "ffa" and 3 or 1),
				waitingSeconds = 0,
				playerNames = { player.DisplayName },
			})
		end
	elseif state.phase == "arena" then
		gui.Enabled = false
	end
end)

startButton.MouseButton1Click:Connect(function()
	Remotes.EnterArena:FireServer()
end)

if cancelButton then
	cancelButton.MouseButton1Click:Connect(function()
		Remotes.LeaveQueue:FireServer()
	end)
end

applyHubOverlay()
