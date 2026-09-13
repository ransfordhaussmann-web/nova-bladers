local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = playerGui:WaitForChild("QueueOverlay")
local panel = gui:WaitForChild("Panel")
local statusLabel = panel:WaitForChild("StatusLabel")
local detailLabel = panel:WaitForChild("DetailLabel")
local leaveButton = panel:WaitForChild("LeaveButton")

local STATUS_TEXT = {
	waiting = "Warte auf Spieler…",
	pending = "Arena belegt — wartet…",
	filling = "Lobby füllt sich…",
}

local function hideOverlay()
	gui.Enabled = false
end

local function showOverlay()
	gui.Enabled = true
end

local function updateOverlay(payload)
	if not payload or payload.status == "idle" then
		hideOverlay()
		return
	end

	showOverlay()
	statusLabel.Text = STATUS_TEXT[payload.status] or "In Warteschlange…"
	detailLabel.Text = string.format(
		"%s\n%d / %d Spieler",
		payload.modeLabel or payload.modeId or "Match",
		payload.queued or 0,
		payload.maxPlayers or 1
	)

	if payload.status == "filling" and payload.fillSecondsLeft then
		detailLabel.Text ..= string.format("\nStart in %ds", payload.fillSecondsLeft)
	end
end

Remotes.QueueUpdate.OnClientEvent:Connect(updateOverlay)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" then
		hideOverlay()
	end
end)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	hideOverlay()
end)
