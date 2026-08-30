local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Queue")
local panel = gui:WaitForChild("Panel")
local titleLabel = panel:WaitForChild("TitleLabel")
local statusLabel = panel:WaitForChild("StatusLabel")
local playersLabel = panel:WaitForChild("PlayersLabel")
local countdownLabel = panel:WaitForChild("CountdownLabel")
local leaveButton = panel:WaitForChild("LeaveButton")

local function formatPlayerList(names)
	if #names == 0 then
		return "Noch keine Spieler"
	end
	return table.concat(names, "\n")
end

local function applyQueueUpdate(payload)
	if not payload or not payload.inQueue then
		gui.Enabled = false
		return
	end

	gui.Enabled = true
	titleLabel.Text = "Warteschlange: " .. (payload.modeLabel or "?")
	statusLabel.Text = string.format(
		"Spieler: %d / %d (min. %d)",
		payload.players or 0,
		payload.maxPlayers or 0,
		payload.needed or 0
	)
	playersLabel.Text = formatPlayerList(payload.playerNames or {})

	if payload.countdown and payload.countdown > 0 then
		countdownLabel.Text = "Start in " .. tostring(payload.countdown) .. "..."
	else
		countdownLabel.Text = "Warte auf Gegner..."
	end
end

Remotes.QueueUpdate.OnClientEvent:Connect(applyQueueUpdate)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "queue" then
		gui.Enabled = true
	else
		gui.Enabled = false
	end
end)

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if payload.queueSnapshot then
		applyQueueUpdate(payload.queueSnapshot)
	elseif not payload.inQueue then
		gui.Enabled = false
	end
end)

Remotes.MatchState.OnClientEvent:Connect(function()
	gui.Enabled = false
end)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.LeaveQueue:FireServer()
end)

gui.Enabled = false
