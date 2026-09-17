local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("MatchQueue")
local panel = gui:WaitForChild("Panel")
local statusLabel = panel:WaitForChild("StatusLabel")
local detailLabel = panel:WaitForChild("DetailLabel")
local leaveButton = panel:WaitForChild("LeaveButton")

local function hideQueue()
	gui.Enabled = false
end

local function showQueue(payload)
	gui.Enabled = true
	statusLabel.Text = string.format("Queue: %s", payload.modeLabel or payload.modeId or "?")

	local parts = {
		string.format("%d / %d Spieler", payload.count or 0, payload.max or 0),
	}

	if payload.fillSeconds and payload.fillSeconds > 0 then
		table.insert(parts, string.format("Start in %ds", payload.fillSeconds))
	end

	if payload.pending then
		table.insert(parts, "Arena belegt — warte...")
	end

	detailLabel.Text = table.concat(parts, " · ")
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if payload.inQueue then
		showQueue(payload)
	else
		hideQueue()
	end
end)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	hideQueue()
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" then
		hideQueue()
	end
end)

hideQueue()
