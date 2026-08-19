local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("QueueOverlay")
local panel = gui:WaitForChild("Panel")
local statusLabel = panel:WaitForChild("StatusLabel")
local detailLabel = panel:WaitForChild("DetailLabel")
local leaveButton = panel:WaitForChild("LeaveButton")

local function hideOthers()
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then
		hud.Enabled = false
	end
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = false
	end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then
		mobile.Enabled = false
	end
end

local function showIdle()
	gui.Enabled = false
	statusLabel.Text = ""
	detailLabel.Text = ""
end

local function formatQueueText(payload)
	local needed = math.max(0, (payload.minPlayers or 1) - (payload.total or 0))
	if needed > 0 then
		return string.format(
			"Warte auf %d weitere Spieler…\nPosition: %d / %d",
			needed,
			payload.position or 1,
			payload.total or 1
		)
	end
	return string.format("Match startet gleich…\n%d Spieler bereit", payload.total or 1)
end

Remotes.QueueState.OnClientEvent:Connect(function(payload)
	if payload.status == "idle" then
		showIdle()
		return
	end

	hideOthers()
	gui.Enabled = true

	if payload.status == "matched" then
		statusLabel.Text = "Match gefunden!"
		detailLabel.Text = string.format("%s — %d Spieler", payload.label or "Arena", payload.total or 1)
		leaveButton.Visible = false
		return
	end

	statusLabel.Text = "Warteschlange: " .. (payload.label or "Arena")
	detailLabel.Text = formatQueueText(payload)
	leaveButton.Visible = true
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		showIdle()
	elseif state.phase == "queue" then
		hideOthers()
		gui.Enabled = true
		statusLabel.Text = "Warteschlange…"
		detailLabel.Text = state.modeLabel or ""
		leaveButton.Visible = true
	elseif state.phase == "arena" then
		gui.Enabled = false
	end
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	showIdle()
end)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.LeaveQueue:FireServer()
end)

showIdle()
