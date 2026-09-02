local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local queueGui = player:WaitForChild("PlayerGui"):WaitForChild("Queue")
local panel = queueGui:WaitForChild("Panel")
local statusLabel = panel:WaitForChild("StatusLabel")
local playersLabel = panel:WaitForChild("PlayersLabel")
local leaveButton = panel:WaitForChild("LeaveButton")

local function hideOthers()
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then
		hud.Enabled = false
	end
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = false
	end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then
		mobile.Enabled = false
	end
end

local function formatQueueStatus(payload)
	local needed = payload.minPlayers - payload.players
	if needed > 0 then
		return string.format(
			"Warteschlange: %s\n%d / %d Spieler",
			payload.modeLabel,
			payload.players,
			payload.minPlayers
		)
	end
	return string.format(
		"Warteschlange: %s\n%d / %d — Start bald…",
		payload.modeLabel,
		payload.players,
		payload.maxPlayers
	)
end

local function formatQueuedNames(names)
	if #names == 0 then
		return ""
	end
	return "Spieler:\n" .. table.concat(names, "\n")
end

local function showQueue(payload)
	hideOthers()
	statusLabel.Text = formatQueueStatus(payload)
	playersLabel.Text = formatQueuedNames(payload.queuedNames)
	queueGui.Enabled = true
end

local function hideQueue()
	queueGui.Enabled = false
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	showQueue(payload)
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "queue" then
		hideOthers()
		queueGui.Enabled = true
		if state.modeId then
			statusLabel.Text = string.format("Warteschlange: %s\nVerbinde…", state.modeId)
		end
	elseif state.phase == "hub" then
		hideQueue()
	elseif state.phase == "arena" then
		hideQueue()
	end
end)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.LeaveQueue:FireServer()
end)

hideQueue()
