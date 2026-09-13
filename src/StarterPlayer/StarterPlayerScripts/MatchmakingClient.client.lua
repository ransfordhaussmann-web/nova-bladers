local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local queuePanel = gui:WaitForChild("QueuePanel")

local title = queuePanel:WaitForChild("Title")
local statusLabel = queuePanel:WaitForChild("StatusLabel")
local leaveButton = queuePanel:WaitForChild("LeaveButton")

local STATUS_TEXT = {
	waiting = "Warte auf Spieler…",
	pending = "Arena belegt — du bist vorgemerkt",
	fill = "Fast voll — Match startet gleich",
	starting = "Match startet…",
}

local function hideQueuePanel()
	queuePanel.Visible = false
end

local function showQueuePanel()
	queuePanel.Visible = true
end

local function applyQueueUpdate(payload)
	if not payload.inQueue then
		hideQueuePanel()
		return
	end

	showQueuePanel()
	title.Text = string.format("Warteschlange: %s", payload.modeLabel or payload.mode or "?")

	local lines = {
		string.format("%d / %d Spieler", payload.playersInQueue or 0, payload.maxPlayers or 0),
	}

	local statusKey = payload.status or "waiting"
	table.insert(lines, STATUS_TEXT[statusKey] or STATUS_TEXT.waiting)

	if payload.fillSecondsLeft and payload.fillSecondsLeft > 0 then
		table.insert(lines, string.format("Start in %ds", payload.fillSecondsLeft))
	end

	statusLabel.Text = table.concat(lines, "\n")
end

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
end)

Remotes.QueueUpdate.OnClientEvent:Connect(applyQueueUpdate)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" then
		hideQueuePanel()
	end
end)

hideQueuePanel()
