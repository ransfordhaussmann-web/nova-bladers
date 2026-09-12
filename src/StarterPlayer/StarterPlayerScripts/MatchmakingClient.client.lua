local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")
local queuePanel = panel:WaitForChild("QueuePanel")
local queueLabel = queuePanel:WaitForChild("QueueLabel")
local leaveButton = queuePanel:WaitForChild("LeaveButton")

local function formatQueueText(payload)
	if payload.status == "pending" then
		return string.format(
			"⏳ %s\nWarte auf freie Arena…\n%d / %d Spieler",
			payload.label,
			payload.count,
			payload.maxPlayers
		)
	end

	return string.format(
		"🔍 %s\nSuche Gegner…\n%d / %d Spieler",
		payload.label,
		payload.count,
		payload.maxPlayers
	)
end

local function showQueue(payload)
	queueLabel.Text = formatQueueText(payload)
	queuePanel.Visible = true
end

local function hideQueue()
	queuePanel.Visible = false
	queueLabel.Text = ""
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if payload.inQueue then
		showQueue(payload)
	else
		hideQueue()
	end
end)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	hideQueue()
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" then
		hideQueue()
	end
end)

hideQueue()
