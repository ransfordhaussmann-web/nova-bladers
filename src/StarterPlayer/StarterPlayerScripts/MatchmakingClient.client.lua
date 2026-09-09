local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Matchmaking")
local panel = gui:WaitForChild("Panel")
local statusLabel = panel:WaitForChild("StatusLabel")
local playersLabel = panel:WaitForChild("PlayersLabel")
local leaveButton = panel:WaitForChild("LeaveButton")

local function showPanel(visible)
	gui.Enabled = visible
end

local function formatQueueText(payload)
	if not payload.inQueue then
		return ""
	end

	local lines = {
		string.format("Warteschlange: %s", payload.modeLabel or payload.modeId or "?"),
		string.format("%d / %d Spieler", payload.queued or 0, payload.needed or 0),
	}

	if payload.gathering then
		table.insert(lines, "Match startet gleich...")
	elseif payload.queued and payload.needed and payload.queued < payload.needed then
		table.insert(lines, string.format("Noch %d benötigt", payload.needed - payload.queued))
	end

	if payload.position then
		table.insert(lines, string.format("Position: %d", payload.position))
	end

	return table.concat(lines, "\n")
end

local function formatPlayersText(payload)
	if not payload.inQueue or not payload.players then
		return ""
	end
	if #payload.players == 0 then
		return "Warte auf Spieler..."
	end
	return "Spieler:\n" .. table.concat(payload.players, "\n")
end

local function applyQueueUpdate(payload)
	if payload.inQueue then
		statusLabel.Text = formatQueueText(payload)
		playersLabel.Text = formatPlayersText(payload)
		showPanel(true)
	else
		showPanel(false)
	end
end

Remotes.QueueUpdate.OnClientEvent:Connect(applyQueueUpdate)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		showPanel(false)
	elseif state.phase == "arena" then
		showPanel(false)
	end
end)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.LeaveQueue:FireServer()
	showPanel(false)
end)

showPanel(false)
