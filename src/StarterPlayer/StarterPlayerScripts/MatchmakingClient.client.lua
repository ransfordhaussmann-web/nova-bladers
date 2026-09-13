local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")
local queuePanel = panel:WaitForChild("QueuePanel")

local title = queuePanel:WaitForChild("Title")
local detail = queuePanel:WaitForChild("Detail")
local leaveButton = queuePanel:WaitForChild("LeaveButton")

local inQueue = false

local function showQueue(payload)
	inQueue = payload.status ~= "idle"
	queuePanel.Visible = inQueue

	if not inQueue then
		return
	end

	local statusLine = "Warte auf Mitspieler…"
	if payload.status == "pending" then
		statusLine = "Arena belegt — du bist als Nächstes dran"
	end

	title.Text = string.format("⏳ %s", payload.modeLabel or "Warteschlange")
	detail.Text = string.format(
		"%s\n%d / %d Spieler\n%s",
		statusLine,
		payload.count or 0,
		payload.maxPlayers or 1,
		payload.players and #payload.players > 0 and table.concat(payload.players, ", ") or "—"
	)
end

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	showQueue({ status = "idle" })
end)

Remotes.QueueUpdate.OnClientEvent:Connect(showQueue)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" and not inQueue then
		queuePanel.Visible = false
	elseif state.phase == "arena" then
		inQueue = false
		queuePanel.Visible = false
	end
end)

Remotes.MatchState.OnClientEvent:Connect(function()
	inQueue = false
	queuePanel.Visible = false
end)
