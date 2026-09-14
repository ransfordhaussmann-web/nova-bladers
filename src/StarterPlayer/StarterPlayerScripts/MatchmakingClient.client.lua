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
	statusLabel.Text = payload.pending and "Warteschlange (Arena belegt)" or "In Warteschlange"
	local detail = string.format(
		"%s — %d/%d Spieler",
		payload.modeLabel or payload.modeId or "?",
		payload.count or 0,
		payload.maxPlayers or 1
	)
	if payload.fillSeconds and not payload.pending then
		detail ..= string.format("\nStart in max. %ds", payload.fillSeconds)
	end
	detailLabel.Text = detail
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
