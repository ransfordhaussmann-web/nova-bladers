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
		panel.Size = UDim2.fromOffset(280, 250)
	end
	local startButton = panel:FindFirstChild("StartButton")
	if startButton then
		startButton.Text = "Schnellmatch"
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

local function formatQueueStatus(payload)
	if payload.inQueue and payload.queuedModeId then
		local sizes = payload.queueSizes or {}
		local waiting = sizes[payload.queuedModeId] or 0
		return string.format("In Warteschlange (%s): %d Spieler", payload.queuedModeId, waiting)
	end

	local sizes = payload.queueSizes
	if not sizes then
		return ""
	end
	return string.format("Warteschlange — Training: %d | 1v1: %d | FFA: %d", sizes.training or 0, sizes.pvp or 0, sizes.ffa or 0)
end

local function updateQueueUi(payload)
	local queueLabel = panel:FindFirstChild("QueueLabel")
	local leaveButton = panel:FindFirstChild("LeaveQueueButton")
	if queueLabel then
		queueLabel.Text = formatQueueStatus(payload)
	end
	if leaveButton then
		leaveButton.Visible = payload.inQueue == true
	end
end

local function updateStats(payload)
	panel.StatsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d",
		payload.wins, payload.losses, payload.rank
	)
	panel.ModeLabel.Text = payload.modeLabel or "Wähle einen Modus"
	updateQueueUi(payload)
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
	elseif state.phase == "queued" then
		gui.Enabled = true
		enableWalking()
		if state.modeLabel and panel:FindFirstChild("ModeLabel") then
			panel.ModeLabel.Text = state.modeLabel
		end
	elseif state.phase == "arena" then
		gui.Enabled = false
	end
end)

Remotes.QueueUpdate.OnClientEvent:Connect(function(snapshot)
	local queueLabel = panel:FindFirstChild("QueueLabel")
	local leaveButton = panel:FindFirstChild("LeaveQueueButton")
	if snapshot.inQueue then
		if queueLabel then
			local needed = snapshot.needed or 0
			if needed > 0 then
				queueLabel.Text = string.format("Wartest auf %s — noch %d Spieler", snapshot.modeLabel, needed)
			else
				queueLabel.Text = string.format("Match startet bald (%s)", snapshot.modeLabel)
			end
		end
		if leaveButton then
			leaveButton.Visible = true
		end
		if panel:FindFirstChild("ModeLabel") then
			panel.ModeLabel.Text = "Modus: " .. (snapshot.modeLabel or snapshot.modeId)
		end
	else
		if queueLabel then
			queueLabel.Text = ""
		end
		if leaveButton then
			leaveButton.Visible = false
		end
	end
end)

local queueButtons = panel:FindFirstChild("QueueButtons")
if queueButtons then
	for _, child in queueButtons:GetChildren() do
		if child:IsA("TextButton") then
			child.MouseButton1Click:Connect(function()
				local modeId = child:GetAttribute("ModeId")
				if modeId then
					Remotes.QueueJoin:FireServer(modeId)
				end
			end)
		end
	end
end

local leaveButton = panel:FindFirstChild("LeaveQueueButton")
if leaveButton then
	leaveButton.MouseButton1Click:Connect(function()
		Remotes.QueueLeave:FireServer()
	end)
end

panel.StartButton.MouseButton1Click:Connect(function()
	Remotes.EnterArena:FireServer()
end)

applyHubOverlay()
