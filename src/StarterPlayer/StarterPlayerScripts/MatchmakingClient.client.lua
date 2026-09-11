local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchState = require(ReplicatedStorage.NovaBladers.MatchState)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = playerGui:WaitForChild("QueueOverlay")
local panel = gui:WaitForChild("Panel")
local statusLabel = panel:WaitForChild("StatusLabel")
local detailLabel = panel:WaitForChild("DetailLabel")
local leaveButton = panel:WaitForChild("LeaveButton")

local function formatDetail(payload)
	local lines = {
		string.format("Modus: %s", payload.modeLabel or "?"),
		string.format("Spieler: %d / %d", payload.playersInQueue or 0, payload.maxPlayers or 0),
	}

	if payload.fillTimeoutRemaining and payload.fillTimeoutRemaining > 0 then
		table.insert(lines, string.format("Start in ~%ds", payload.fillTimeoutRemaining))
	end

	return table.concat(lines, "\n")
end

local function applyQueueState(payload)
	if not payload or payload.status == MatchState.QueueStatus.Idle then
		gui.Enabled = false
		return
	end

	gui.Enabled = true

	if payload.status == MatchState.QueueStatus.Pending then
		statusLabel.Text = "Arena belegt — warte..."
	elseif payload.status == MatchState.QueueStatus.Searching then
		statusLabel.Text = "Suche Mitspieler..."
	else
		statusLabel.Text = "Warteschlange"
	end

	detailLabel.Text = formatDetail(payload)
end

Remotes.QueueUpdate.OnClientEvent:Connect(applyQueueState)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	gui.Enabled = false
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" then
		gui.Enabled = false
	end
end)
