local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")
local startButton = panel:WaitForChild("StartButton")
local queueLabel = panel:FindFirstChild("QueueLabel")
if not queueLabel then
	queueLabel = Instance.new("TextLabel")
	queueLabel.Name = "QueueLabel"
	queueLabel.Size = UDim2.new(1, -16, 0, 28)
	queueLabel.Position = UDim2.fromOffset(8, 132)
	queueLabel.BackgroundTransparency = 1
	queueLabel.Font = Enum.Font.GothamMedium
	queueLabel.TextSize = 12
	queueLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
	queueLabel.TextXAlignment = Enum.TextXAlignment.Left
	queueLabel.TextYAlignment = Enum.TextYAlignment.Top
	queueLabel.Text = ""
	queueLabel.Visible = false
	queueLabel.Parent = panel
end

local inQueue = false

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
	local startButton = panel:FindFirstChild("StartButton")
	if startButton then
		startButton.Text = "Arena (Fallback)"
		startButton.Size = UDim2.fromOffset(120, 28)
	end
end

local function updateQueueUI(payload)
	if not queueLabel then
		return
	end

	if not payload.inQueue then
		inQueue = false
		queueLabel.Visible = false
		startButton.Text = "Arena beitreten"
		startButton.BackgroundColor3 = Color3.fromRGB(60, 120, 255)
		return
	end

	inQueue = true
	queueLabel.Visible = true
	panel.ModeLabel.Text = payload.modeLabel or panel.ModeLabel.Text

	if payload.status == "starting" and payload.countdown then
		queueLabel.Text = string.format("Start in %ds (%d Spieler)", payload.countdown, payload.queueSize or 1)
		startButton.Text = "Warteschlange verlassen"
		startButton.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
	elseif payload.queueSize and payload.queueSize >= (payload.minPlayers or 2) then
		queueLabel.Text = string.format("Bereit: %d Spieler — warte auf Start", payload.queueSize)
		startButton.Text = "Warteschlange verlassen"
		startButton.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
	else
		queueLabel.Text = string.format(
			"Warteschlange: %d/%d Spieler",
			payload.queueSize or 1,
			payload.minPlayers or 2
		)
		startButton.Text = "Warteschlange verlassen"
		startButton.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
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
		inQueue = false
		if queueLabel then
			queueLabel.Visible = false
		end
		startButton.Text = "Arena beitreten"
		startButton.BackgroundColor3 = Color3.fromRGB(60, 120, 255)
	elseif state.phase == "arena" then
		gui.Enabled = true
	end
end)

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	gui.Enabled = true
	updateQueueUI(payload)
end)

panel.StartButton.MouseButton1Click:Connect(function()
	if inQueue then
		Remotes.QueueLeave:FireServer()
	else
		gui.Enabled = false
		Remotes.EnterArena:FireServer()
	end
end)

applyHubOverlay()
