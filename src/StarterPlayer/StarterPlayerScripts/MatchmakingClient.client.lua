local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("MatchmakingQueue")
local panel = gui:WaitForChild("Panel")
local statusLabel = panel:WaitForChild("StatusLabel")
local detailLabel = panel:WaitForChild("DetailLabel")
local leaveButton = panel:WaitForChild("LeaveButton")

local function showQueue(payload)
	gui.Enabled = true
	statusLabel.Text = payload.modeLabel or "Matchmaking"
	if payload.statusText then
		detailLabel.Text = payload.statusText
	elseif payload.queueSize and payload.needed then
		if payload.needed > 0 then
			detailLabel.Text = string.format(
				"In Queue (%d/%d) — noch %d Spieler",
				payload.queueSize,
				payload.queueSize + payload.needed,
				payload.needed
			)
		else
			detailLabel.Text = string.format("In Queue (%d Spieler)", payload.queueSize)
		end
	else
		detailLabel.Text = "Suche Gegner..."
	end
end

local function hideQueue()
	gui.Enabled = false
	statusLabel.Text = "Matchmaking"
	detailLabel.Text = ""
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if not payload or payload.status == "idle" then
		hideQueue()
		return
	end
	showQueue(payload)
end)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	hideQueue()
end)

hideQueue()
