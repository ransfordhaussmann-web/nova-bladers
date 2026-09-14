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
	if payload.status == "pending" then
		return "Arena belegt — warte..."
	elseif payload.status == "filling" then
		return string.format("Spieler gesucht (%d/%d)", payload.players, payload.maxPlayers)
	end
	return string.format("Warteschlange (%d/%d)", payload.players, payload.needed)
end

local function formatDetail(payload)
	local lines = { payload.modeLabel or "Match" }
	if payload.fillRemaining then
		table.insert(lines, string.format("Start in %ds", payload.fillRemaining))
	elseif payload.status == "pending" then
		table.insert(lines, "Nächstes Match startet gleich")
	end
	return table.concat(lines, "\n")
end

local function showQueue(payload)
	queuePanel.Visible = true
	statusLabel.Text = formatStatus(payload)
	detailLabel.Text = formatDetail(payload)
end

local function hideQueue()
	queuePanel.Visible = false
	statusLabel.Text = ""
	detailLabel.Text = ""
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
