local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Queue")
local panel = gui:WaitForChild("Panel")
local statusLabel = panel:WaitForChild("StatusLabel")
local detailLabel = panel:WaitForChild("DetailLabel")
local leaveButton = panel:WaitForChild("LeaveButton")

local function showQueue(payload)
	if payload.waitingForArena then
		statusLabel.Text = "Match bereit — Arena belegt"
	else
		statusLabel.Text = "In Warteschlange"
	end
	detailLabel.Text = string.format(
		"%s\nSpieler: %d / %d",
		payload.modeLabel or "Arena",
		payload.current or 0,
		payload.needed or 1
	)
	gui.Enabled = true
end

local function hideQueue()
	gui.Enabled = false
	statusLabel.Text = ""
	detailLabel.Text = ""
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if payload.inQueue then
		showQueue(payload)
	else
		hideQueue()
	end
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		hideQueue()
	elseif state.phase == "arena" then
		hideQueue()
	end
end)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	hideQueue()
end)
