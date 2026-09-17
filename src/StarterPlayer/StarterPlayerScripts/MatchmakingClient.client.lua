local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = playerGui:WaitForChild("Matchmaking")
local panel = gui:WaitForChild("Panel")
local statusLabel = panel:WaitForChild("StatusLabel")
local detailLabel = panel:WaitForChild("DetailLabel")
local leaveButton = panel:WaitForChild("LeaveButton")

local function formatStatus(payload)
	if payload.status == "pending" then
		return "Arena belegt — warte..."
	end
	if payload.fillRemaining and payload.fillRemaining > 0 then
		return string.format("Start in %ds", payload.fillRemaining)
	end
	if payload.playersInQueue < payload.minPlayers then
		return "Warte auf Spieler..."
	end
	return "Match startet gleich!"
end

local function formatDetail(payload)
	return string.format(
		"%s\n%d / %d Spieler",
		payload.modeLabel or "Warteschlange",
		payload.playersInQueue or 0,
		payload.maxPlayers or 1
	)
end

local function showQueue(payload)
	statusLabel.Text = formatStatus(payload)
	detailLabel.Text = formatDetail(payload)
	gui.Enabled = true
end

local function hideQueue()
	gui.Enabled = false
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

hideQueue()
