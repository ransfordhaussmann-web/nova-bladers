local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local queuePanel = gui:WaitForChild("QueuePanel")

local statusLabel = queuePanel:WaitForChild("StatusLabel")
local detailLabel = queuePanel:WaitForChild("DetailLabel")
local leaveButton = queuePanel:WaitForChild("LeaveButton")

local function showQueuePanel()
	queuePanel.Visible = true
end

local function hideQueuePanel()
	queuePanel.Visible = false
end

local function formatQueueText(payload)
	if payload.matchStarting then
		return "Match startet...", "Bereite dich vor!"
	end

	if not payload.inQueue then
		return "", ""
	end

	local modeLabel = payload.modeLabel or payload.modeId or "Queue"
	local queued = payload.queued or 0
	local needed = payload.needed or 1
	local maxPlayers = payload.maxPlayers or needed

	local status = string.format("In Queue: %s", modeLabel)
	local detail

	if payload.pending then
		detail = string.format("%d/%d — Arena belegt, warte...", queued, needed)
	elseif needed == maxPlayers then
		detail = string.format("%d/%d Spieler", queued, needed)
	else
		detail = string.format("%d/%d (max %d)", queued, needed, maxPlayers)
	end

	return status, detail
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if payload.matchStarting then
		showQueuePanel()
		statusLabel.Text = "Match startet..."
		detailLabel.Text = "Bereite dich vor!"
		return
	end

	if payload.inQueue then
		showQueuePanel()
		local status, detail = formatQueueText(payload)
		statusLabel.Text = status
		detailLabel.Text = detail
	else
		hideQueuePanel()
	end
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		hideQueuePanel()
	elseif state.phase == "queue" then
		showQueuePanel()
		statusLabel.Text = string.format("In Queue: %s", state.modeLabel or state.modeId or "")
		detailLabel.Text = "Suche Mitspieler..."
	elseif state.phase == "arena" then
		hideQueuePanel()
	end
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	hideQueuePanel()
end)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	hideQueuePanel()
end)

hideQueuePanel()
