local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local queuePanel = gui:WaitForChild("QueuePanel")
local statusLabel = queuePanel:WaitForChild("StatusLabel")
local countLabel = queuePanel:WaitForChild("CountLabel")
local leaveButton = queuePanel:WaitForChild("LeaveButton")

local function statusText(status)
	if status == "pending" then
		return "Wartet auf Arena..."
	elseif status == "ready" then
		return "Match startet gleich!"
	end
	return "Suche Mitspieler..."
end

local function showQueue(payload)
	queuePanel.Visible = true
	statusLabel.Text = string.format("%s — %s", payload.modeLabel or "Queue", statusText(payload.status))
	countLabel.Text = string.format(
		"%d / %d Spieler",
		payload.count or 0,
		payload.maxPlayers or 1
	)
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
	end
end)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	hideQueue()
end)
