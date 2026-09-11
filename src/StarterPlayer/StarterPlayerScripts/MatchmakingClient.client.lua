local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")
local queueFrame = panel:WaitForChild("QueueFrame")
local queueStatus = queueFrame:WaitForChild("StatusLabel")
local queueDetail = queueFrame:WaitForChild("DetailLabel")
local leaveButton = queueFrame:WaitForChild("LeaveButton")

local MODE_LABELS = {
	training = "Training",
	pvp = "1v1 PvP",
	ffa = "FFA",
}

local function formatQueueText(payload)
	if not payload.inQueue then
		return nil
	end

	local modeLabel = payload.label or MODE_LABELS[payload.modeId] or payload.modeId
	local lines = { string.format("Warteschlange: %s", modeLabel) }

	if payload.status == "pending" or payload.arenaBusy then
		table.insert(lines, "Arena belegt — warte auf freien Slot")
	elseif payload.modeId == "ffa" and payload.secondsLeft then
		table.insert(lines, string.format(
			"%d/%d Spieler — Start in %ds",
			payload.queued or 0,
			payload.maxPlayers or 6,
			payload.secondsLeft
		))
	else
		table.insert(lines, string.format(
			"%d/%d Spieler",
			payload.queued or 0,
			payload.minPlayers or 1
		))
	end

	return table.concat(lines, "\n")
end

local function showQueue(payload)
	local text = formatQueueText(payload)
	if not text then
		queueFrame.Visible = false
		return
	end

	queueFrame.Visible = true
	queueStatus.Text = text
	queueDetail.Text = "Drücke Verlassen um die Queue zu verlassen"
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	showQueue(payload)
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" then
		queueFrame.Visible = false
	end
end)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
end)

queueFrame.Visible = false
