local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local queuePanel = gui:WaitForChild("QueuePanel")
local queueModeLabel = queuePanel:WaitForChild("ModeLabel")
local queueStatusLabel = queuePanel:WaitForChild("StatusLabel")
local queueCountLabel = queuePanel:WaitForChild("CountLabel")
local leaveButton = queuePanel:WaitForChild("LeaveButton")

local function showQueue(payload)
	queuePanel.Visible = true
	queueModeLabel.Text = payload.modeLabel or "Warteschlange"
	queueCountLabel.Text = string.format(
		"%d / %d Spieler",
		payload.queued or 0,
		payload.maxPlayers or 1
	)

	if payload.status == "pending" then
		queueStatusLabel.Text = "Arena belegt — warte..."
	elseif payload.modeId == "ffa" and (payload.queued or 0) < (payload.maxPlayers or 6) then
		queueStatusLabel.Text = "Suche weitere Spieler..."
	else
		queueStatusLabel.Text = "Match startet bald..."
	end
end

local function hideQueue()
	queuePanel.Visible = false
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if payload.inQueue then
		showQueue(payload)
	else
		hideQueue()
	end
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" then
		hideQueue()
		gui.Enabled = false
	elseif state.phase == "hub" then
		gui.Enabled = true
	end
end)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
end)
