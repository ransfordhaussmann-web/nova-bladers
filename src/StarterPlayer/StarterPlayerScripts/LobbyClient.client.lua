local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")

local MODE_BUTTONS = {
	QueueTraining = "training",
	QueuePvP = "pvp",
	QueueFFA = "ffa",
}

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
		panel.Size = UDim2.fromOffset(280, 300)
	end
	local startButton = panel:FindFirstChild("StartButton")
	if startButton then
		startButton.Text = "Quick Queue"
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

local function updateStats(payload)
	panel.StatsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d",
		payload.wins, payload.losses, payload.rank
	)
	panel.ModeLabel.Text = payload.modeLabel or "Modus: Training"
	activeModeId = payload.activeModeId or activeModeId
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

local function formatQueueStatus(payload)
	local counts = payload.counts or {}
	local requirements = payload.requirements or {}
	local labels = payload.labels or {}
	local lines = {}

	if payload.yourMode then
		table.insert(lines, ("In Queue: %s"):format(labels[payload.yourMode] or payload.yourMode))
	else
		table.insert(lines, "Queue: nicht angemeldet")
	end

	for _, modeId in { "training", "pvp", "ffa" } do
		local label = labels[modeId] or modeId
		local need = requirements[modeId] or 1
		table.insert(lines, string.format("%s: %d/%d", label, counts[modeId] or 0, need))
	end

	return table.concat(lines, "\n")
end

local function updateQueueDisplay(payload)
	local status = panel:FindFirstChild("QueueStatus")
	if status then
		status.Text = formatQueueStatus(payload)
	end

	for buttonName, modeId in MODE_BUTTONS do
		local btn = panel:FindFirstChild("QueueRow") and panel.QueueRow:FindFirstChild(buttonName)
		if btn then
			btn.BackgroundTransparency = payload.yourMode == modeId and 0 or 0.15
		end
	end
end

local function wireQueueButtons()
	local queueRow = panel:FindFirstChild("QueueRow")
	if not queueRow then
		return
	end

	for buttonName, modeId in MODE_BUTTONS do
		local btn = queueRow:FindFirstChild(buttonName)
		if btn then
			btn.MouseButton1Click:Connect(function()
				Remotes.MatchQueueJoin:FireServer(modeId)
			end)
		end
	end

	local leaveBtn = panel:FindFirstChild("LeaveQueueButton")
	if leaveBtn then
		leaveBtn.MouseButton1Click:Connect(function()
			Remotes.MatchQueueLeave:FireServer()
		end)
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

Remotes.MatchQueueUpdate.OnClientEvent:Connect(function(payload)
	updateQueueDisplay(payload)
end)

panel.StartButton.MouseButton1Click:Connect(function()
	Remotes.MatchQueueJoin:FireServer(activeModeId)
end)

applyHubOverlay()
wireQueueButtons()
