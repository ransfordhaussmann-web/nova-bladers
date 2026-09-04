local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")
local queueLabel = panel:WaitForChild("QueueLabel")
local leaveButton = panel:WaitForChild("LeaveQueueButton")

local function setQueueVisible(inQueue)
	leaveButton.Visible = inQueue
end

local function updateQueue(payload)
	if not payload then
		return
	end

	if payload.inQueue then
		local modeText = payload.modeLabel or payload.mode or "Arena"
		queueLabel.Text = string.format(
			"⏳ %s\n%s",
			modeText,
			payload.statusMessage or "In Warteschlange..."
		)
		setQueueVisible(true)
	else
		queueLabel.Text = payload.statusMessage or "Modus-Pad oder Portal nutzen."
		setQueueVisible(false)
	end
end

Remotes.MatchmakingUpdate.OnClientEvent:Connect(updateQueue)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.MatchmakingLeave:FireServer()
end)

updateQueue({ inQueue = false, statusMessage = "Modus-Pad oder Portal nutzen." })
