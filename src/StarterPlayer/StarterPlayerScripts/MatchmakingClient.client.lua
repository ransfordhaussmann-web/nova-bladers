local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")

local queueStatusLabel = panel:WaitForChild("QueueStatusLabel")
local leaveQueueButton = panel:WaitForChild("LeaveQueueButton")

local MODE_BUTTONS = {
	QueueTraining = "training",
	QueuePvP = "pvp",
	QueueFFA = "ffa",
}

local function formatQueueLines(queues)
	if not queues then
		return ""
	end
	local lines = {}
	for _, mode in { "training", "pvp", "ffa" } do
		local info = queues[mode]
		if info then
			table.insert(lines, info.label)
		end
	end
	return table.concat(lines, "\n")
end

local function updateQueueUI(payload)
	local inQueue = payload.inQueue == true
	leaveQueueButton.Visible = inQueue

	if inQueue and payload.queues and payload.mode then
		local info = payload.queues[payload.mode]
		if info then
			queueStatusLabel.Text = "⏳ " .. info.label
		end
	else
		queueStatusLabel.Text = formatQueueLines(payload.queues)
	end
end

for buttonName, mode in MODE_BUTTONS do
	local btn = panel:FindFirstChild(buttonName)
	if btn then
		btn.MouseButton1Click:Connect(function()
			Remotes.MatchmakingJoin:FireServer(mode)
		end)
	end
end

leaveQueueButton.MouseButton1Click:Connect(function()
	Remotes.MatchmakingLeave:FireServer()
end)

Remotes.MatchmakingStatus.OnClientEvent:Connect(updateQueueUI)
