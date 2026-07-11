local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")

local MODE_NAMES = {
	training = "Training",
	pvp = "1v1 PvP",
	ffa = "FFA",
}

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
		panel.Size = UDim2.fromOffset(280, 280)
	end
	local startButton = panel:FindFirstChild("StartButton")
	if startButton then
		startButton.Text = "Schnell-Match"
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

local function updateQueueButtons(counts)
	counts = counts or {}
	for _, child in panel:FindFirstChild("QueueFrame"):GetChildren() do
		if child:IsA("TextButton") and child.Name:match("^QueueBtn_") then
			local modeId = child.Name:gsub("^QueueBtn_", "")
			local count = counts[modeId] or 0
			local baseLabel = MODE_NAMES[modeId] or modeId
			child.Text = string.format("%s (%d)", baseLabel:sub(1, 5), count)
		end
	end
end

local function updateQueueStatus(payload)
	local statusLabel = panel:FindFirstChild("QueueStatusLabel")
	local leaveBtn = panel:FindFirstChild("LeaveQueueButton")
	if not statusLabel then
		return
	end

	if payload.inQueue or payload.queued then
		local modeId = payload.queueMode or payload.mode
		local modeName = MODE_NAMES[modeId] or modeId or "?"
		local needed = payload.playersNeeded
		if needed and needed > 0 then
			statusLabel.Text = string.format("Warte auf %s … (%d Spieler fehlen)", modeName, needed)
		else
			statusLabel.Text = string.format("Warte auf %s …", modeName)
		end
		if leaveBtn then
			leaveBtn.Visible = true
		end
	else
		statusLabel.Text = "Mode-Pads oder Buttons zum Beitreten"
		if leaveBtn then
			leaveBtn.Visible = false
		end
	end

	if payload.queueCounts or payload.counts then
		updateQueueButtons(payload.queueCounts or payload.counts)
	end
end

local function updateStats(payload)
	panel.StatsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d",
		payload.wins, payload.losses, payload.rank
	)
	panel.ModeLabel.Text = payload.modeLabel or "Modus: Training"
	updateQueueStatus(payload)
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	hideOthers()
	applyHubOverlay()
	updateStats(payload)
	gui.Enabled = true
	enableWalking()
end)

Remotes.QueueState.OnClientEvent:Connect(function(payload)
	updateQueueStatus(payload)
	if payload.queued then
		gui.Enabled = true
	end
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		hideOthers()
		applyHubOverlay()
		gui.Enabled = true
		enableWalking()
		updateQueueStatus({ queued = false, counts = state.queueCounts })
	elseif state.phase == "queue" then
		gui.Enabled = true
		updateQueueStatus({
			queued = true,
			mode = state.mode,
			playersNeeded = state.playersNeeded,
		})
	elseif state.phase == "arena" then
		gui.Enabled = false
	end
end)

panel.StartButton.MouseButton1Click:Connect(function()
	Remotes.JoinQueue:FireServer("auto")
end)

local queueFrame = panel:FindFirstChild("QueueFrame")
if queueFrame then
	for _, child in queueFrame:GetChildren() do
		if child:IsA("TextButton") and child.Name:match("^QueueBtn_") then
			local modeId = child.Name:gsub("^QueueBtn_", "")
			child.MouseButton1Click:Connect(function()
				Remotes.JoinQueue:FireServer(modeId)
			end)
		end
	end
end

local leaveBtn = panel:FindFirstChild("LeaveQueueButton")
if leaveBtn then
	leaveBtn.MouseButton1Click:Connect(function()
		Remotes.LeaveQueue:FireServer()
	end)
end

applyHubOverlay()
