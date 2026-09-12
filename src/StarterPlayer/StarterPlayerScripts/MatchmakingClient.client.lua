local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("MatchQueue")
local panel = gui:WaitForChild("Panel")
local titleLabel = panel:WaitForChild("TitleLabel")
local statusLabel = panel:WaitForChild("StatusLabel")
local leaveButton = panel:WaitForChild("LeaveButton")

local function showQueue(status)
	gui.Enabled = true
	titleLabel.Text = "Warteschlange: " .. (status.modeLabel or "?")

	local lines = {}
	if status.pending then
		table.insert(lines, "Arena belegt — du bist als Nächstes dran.")
	end

	table.insert(lines, string.format("Spieler: %d / %d", status.count or 0, status.needed or 0))

	if status.fillSecondsLeft and status.fillSecondsLeft > 0 then
		table.insert(lines, string.format("Start in %ds…", status.fillSecondsLeft))
	elseif status.count and status.minPlayers and status.count < status.minPlayers then
		table.insert(lines, string.format("Warte auf %d+ Spieler…", status.minPlayers))
	end

	statusLabel.Text = table.concat(lines, "\n")
end

local function hideQueue()
	gui.Enabled = false
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(status)
	if status.inQueue then
		showQueue(status)
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

hideQueue()
