local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local queuePanel = gui:WaitForChild("QueuePanel")
local statusLabel = queuePanel:WaitForChild("StatusLabel")
local detailLabel = queuePanel:WaitForChild("DetailLabel")
local leaveButton = queuePanel:WaitForChild("LeaveButton")

local function formatStatus(payload)
	if not payload.inQueue then
		return "Nicht in der Queue"
	end

	if payload.status == "pending" then
		return string.format("Warte auf Arena — %s", payload.modeLabel or "")
	end

	if payload.status == "filling" and payload.fillSecondsLeft then
		return string.format("Match startet in %ds — %s", payload.fillSecondsLeft, payload.modeLabel or "")
	end

	return string.format("In Queue — %s", payload.modeLabel or "")
end

local function formatDetail(payload)
	if not payload.inQueue then
		if payload.arenaBusy then
			return "Arena belegt — Queue startet nach dem Match"
		end
		return "Mode-Pads, Portal oder Schnell-Match nutzen"
	end

	local parts = {
		string.format("%d / %d Spieler", payload.playersInQueue or 0, payload.maxPlayers or 1),
	}

	if payload.status == "pending" then
		table.insert(parts, "Arena noch im Kampf")
	elseif payload.status == "filling" then
		table.insert(parts, "Spieler werden gesucht…")
	elseif (payload.playersInQueue or 0) < (payload.minPlayers or 1) then
		table.insert(parts, string.format("Noch %d Spieler nötig", (payload.minPlayers or 1) - (payload.playersInQueue or 0)))
	end

	return table.concat(parts, " · ")
end

local function applyQueueState(payload)
	local inQueue = payload.inQueue == true
	queuePanel.Visible = inQueue
	statusLabel.Text = formatStatus(payload)
	detailLabel.Text = formatDetail(payload)
end

Remotes.QueueUpdate.OnClientEvent:Connect(applyQueueState)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
end)

queuePanel.Visible = false
