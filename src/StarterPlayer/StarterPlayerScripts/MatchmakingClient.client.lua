local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local queuePanel = gui:WaitForChild("QueuePanel")
local statusLabel = queuePanel:WaitForChild("StatusLabel")
local detailLabel = queuePanel:WaitForChild("DetailLabel")
local leaveButton = queuePanel:WaitForChild("LeaveButton")

local STATUS_TEXT = {
	queued = "In Warteschlange…",
	waiting = "Warte auf weitere Spieler…",
	pending = "Arena belegt — du bist als Nächster dran",
	starting = "Match startet!",
	idle = "",
}

local function hideQueuePanel()
	queuePanel.Visible = false
	statusLabel.Text = ""
	detailLabel.Text = ""
end

local function showQueuePanel(payload)
	queuePanel.Visible = true
	statusLabel.Text = STATUS_TEXT[payload.status] or "In Warteschlange…"

	local detail = string.format(
		"%s — %d/%d Spieler",
		payload.modeLabel or payload.modeId or "Queue",
		payload.queued or 0,
		payload.required or 1
	)

	if payload.status == "pending" then
		detail ..= "\nArena ist noch im Gange"
	elseif payload.status == "waiting" and payload.maxPlayers then
		detail ..= string.format(" (max %d)", payload.maxPlayers)
	end

	if payload.position and payload.position > 0 then
		detail ..= string.format("\nPosition: %d", payload.position)
	end

	detailLabel.Text = detail
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if not payload or payload.status == "idle" then
		hideQueuePanel()
		return
	end
	showQueuePanel(payload)
end)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	hideQueuePanel()
end)

hideQueuePanel()
