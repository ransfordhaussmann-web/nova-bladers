local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local playerGui = player:WaitForChild("PlayerGui")

local function getQueueGui()
	local gui = playerGui:WaitForChild("Queue", 10)
	if not gui then
		return nil
	end
	return gui:WaitForChild("Panel")
end

local function formatStatus(payload)
	if not payload.inQueue then
		return ""
	end

	local queue = payload.queue
	if not queue then
		return "In Warteschlange..."
	end

	if queue.status == "pending" then
		return "Arena belegt — warte auf freie Arena"
	end
	if queue.status == "full" then
		return "Queue voll — Match startet gleich"
	end

	return string.format(
		"%s: %d / %d Spieler",
		queue.modeLabel,
		queue.count,
		queue.maxPlayers
	)
end

local function updateQueuePanel(payload)
	local panel = getQueueGui()
	if not panel then
		return
	end

	local gui = panel.Parent
	if not payload.inQueue then
		gui.Enabled = false
		return
	end

	gui.Enabled = true
	panel.ModeLabel.Text = payload.queue and payload.queue.modeLabel or "Warteschlange"
	panel.StatusLabel.Text = formatStatus(payload)
	panel.PositionLabel.Text = payload.position and ("Platz " .. payload.position) or ""

	if payload.queue and payload.queue.playerNames then
		local lines = {}
		for i, name in payload.queue.playerNames do
			table.insert(lines, string.format("%d. %s", i, name))
		end
		panel.PlayersLabel.Text = table.concat(lines, "\n")
	else
		panel.PlayersLabel.Text = ""
	end
end

Remotes.QueueUpdate.OnClientEvent:Connect(updateQueuePanel)

local panel = getQueueGui()
if panel then
	panel.LeaveButton.MouseButton1Click:Connect(function()
		Remotes.QueueLeave:FireServer()
	end)
end
