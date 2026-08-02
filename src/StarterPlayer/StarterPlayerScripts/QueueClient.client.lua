local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local queuePanel = gui:WaitForChild("QueuePanel")
local queueStatus = queuePanel:WaitForChild("QueueStatus")
local leaveQueueBtn = queuePanel:WaitForChild("LeaveQueueButton")

local function formatQueueText(payload)
	if payload.countdown then
		return string.format(
			"Start in %ds\nModus: %s (%d Spieler)",
			payload.countdown,
			payload.modeLabel or payload.mode or "?",
			payload.count or 0
		)
	end

	local needed = payload.needed or 1
	local count = payload.count or 0
	if count >= needed then
		return string.format(
			"Bereit! (%d/%d)\nModus: %s",
			count,
			needed,
			payload.modeLabel or payload.mode or "?"
		)
	end

	return string.format(
		"Warte auf Spieler… (%d/%d)\nModus: %s",
		count,
		needed,
		payload.modeLabel or payload.mode or "?"
	)
end

local function showQueue(payload)
	queuePanel.Visible = true
	queueStatus.Text = formatQueueText(payload)
end

local function hideQueue()
	queuePanel.Visible = false
end

Remotes.MatchQueueUpdate.OnClientEvent:Connect(function(payload)
	if payload.inQueue == false then
		hideQueue()
		return
	end
	showQueue(payload)
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "queue" then
		queuePanel.Visible = true
	elseif state.phase == "hub" then
		hideQueue()
	elseif state.phase == "arena" then
		hideQueue()
		gui.Enabled = false
	end
end)

leaveQueueBtn.MouseButton1Click:Connect(function()
	Remotes.MatchQueueLeave:FireServer()
	hideQueue()
end)
