local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Queue")
local panel = gui:WaitForChild("Panel")
local statusLabel = panel:WaitForChild("StatusLabel")
local countLabel = panel:WaitForChild("CountLabel")
local leaveButton = panel:WaitForChild("LeaveButton")

local inQueue = false

local function formatCount(payload)
	if not payload then
		return ""
	end
	return string.format("%d / %d Spieler", payload.count, payload.maxPlayers)
end

local function formatStatus(payload, pending)
	if not payload then
		return "Warteschlange"
	end
	if pending then
		return string.format("%s — Arena belegt, warte...", payload.label)
	end
	if payload.count < payload.minPlayers then
		return string.format("%s — Suche Gegner...", payload.label)
	end
	if payload.fillDeadline then
		return string.format("%s — Start bald...", payload.label)
	end
	return string.format("%s — Match bereit!", payload.label)
end

local function showQueue(payload, pending)
	inQueue = payload ~= nil
	gui.Enabled = inQueue
	if not payload then
		return
	end
	statusLabel.Text = formatStatus(payload, pending)
	countLabel.Text = formatCount(payload)
end

local function hideQueue()
	inQueue = false
	gui.Enabled = false
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload, isPersonal)
	if isPersonal == false then
		return
	end
	if payload then
		showQueue(payload, payload.pending == true)
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
