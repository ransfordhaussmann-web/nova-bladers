local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = playerGui:WaitForChild("MatchmakingQueue")
local panel = gui:WaitForChild("Panel")
local statusLabel = panel:WaitForChild("StatusLabel")
local detailLabel = panel:WaitForChild("DetailLabel")
local leaveButton = panel:WaitForChild("LeaveButton")

local function formatQueueText(payload)
	if not payload.inQueue then
		return ""
	end

	local lines = {
		string.format("Warteschlange: %s", payload.modeLabel or "?"),
		string.format("%d / %d Spieler", payload.queued or 0, payload.required or 0),
	}

	if payload.queued and payload.required and payload.queued >= payload.required then
		table.insert(lines, "Match startet gleich...")
	elseif payload.position and payload.position > 0 then
		table.insert(lines, string.format("Position: %d", payload.position))
	end

	return table.concat(lines, "\n")
end

local function applyQueueState(payload)
	if payload.inQueue then
		statusLabel.Text = "In Warteschlange"
		detailLabel.Text = formatQueueText(payload)
		gui.Enabled = true
	else
		gui.Enabled = false
	end
end

Remotes.QueueUpdate.OnClientEvent:Connect(applyQueueState)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" then
		gui.Enabled = false
	end
end)

Remotes.MatchState.OnClientEvent:Connect(function()
	gui.Enabled = false
end)
