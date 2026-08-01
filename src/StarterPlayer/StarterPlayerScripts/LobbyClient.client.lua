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
		panel.Size = UDim2.fromOffset(280, 210)
	end
	local startButton = panel:FindFirstChild("StartButton")
	if startButton then
		startButton.Text = "Queue (Fallback)"
		startButton.Size = UDim2.fromOffset(130, 28)
	end
end

local queueLabel = panel:FindFirstChild("QueueLabel")
if not queueLabel then
	queueLabel = Instance.new("TextLabel")
	queueLabel.Name = "QueueLabel"
	queueLabel.Size = UDim2.new(1, -16, 0, 44)
	queueLabel.Position = UDim2.fromOffset(8, 132)
	queueLabel.BackgroundTransparency = 1
	queueLabel.Font = Enum.Font.GothamMedium
	queueLabel.TextSize = 12
	queueLabel.TextColor3 = Color3.fromRGB(140, 200, 255)
	queueLabel.TextXAlignment = Enum.TextXAlignment.Left
	queueLabel.TextYAlignment = Enum.TextYAlignment.Top
	queueLabel.Text = ""
	queueLabel.Parent = panel
end

local inQueue = false

local function formatQueueSnapshot(snapshot)
	if not snapshot then
		return ""
	end
	local lines = { "Queue:" }
	for _, modeId in { "training", "pvp", "ffa" } do
		local entry = snapshot[modeId]
		if entry then
			table.insert(lines, string.format("%s %d/%d", entry.label, entry.count, entry.required))
		end
	end
	return table.concat(lines, "\n")
end

local function updateQueueStatus(payload)
	if not payload then
		return
	end
	inQueue = payload.inQueue == true
	if payload.inQueue then
		queueLabel.Text = string.format(
			"⏳ In Queue: %s\n%d/%d Spieler · %ds",
			payload.modeLabel or payload.modeId,
			payload.queuedCount or 0,
			payload.requiredCount or 1,
			payload.waitSeconds or 0
		)
		local startButton = panel:FindFirstChild("StartButton")
		if startButton then
			startButton.Text = "Leave Queue"
		end
	else
		queueLabel.Text = formatQueueSnapshot(payload.snapshot)
		local startButton = panel:FindFirstChild("StartButton")
		if startButton then
			startButton.Text = "Queue (Fallback)"
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

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	updateQueueStatus(payload)
end)

panel.StartButton.MouseButton1Click:Connect(function()
	if inQueue then
		Remotes.QueueLeave:FireServer()
	else
		Remotes.EnterArena:FireServer()
	end
end)

applyHubOverlay()
