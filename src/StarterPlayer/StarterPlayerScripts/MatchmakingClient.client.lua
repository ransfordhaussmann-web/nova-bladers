local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("MatchmakingQueue")
local panel = gui:WaitForChild("Panel")
local modeLabel = panel:WaitForChild("ModeLabel")
local statusLabel = panel:WaitForChild("StatusLabel")
local leaveButton = panel:WaitForChild("LeaveButton")

local function showQueue(payload)
	gui.Enabled = true
	modeLabel.Text = payload.modeLabel or "Matchmaking"
	statusLabel.Text = payload.message or "In Warteschlange..."
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

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" then
		hideQueue()
	end
end)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	hideQueue()
end)
