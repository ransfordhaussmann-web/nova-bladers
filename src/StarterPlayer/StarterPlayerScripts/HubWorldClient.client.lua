local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local inHub = true
local hubFolder

local function waitForHub()
	hubFolder = workspace:WaitForChild(HubConfig.HUB_FOLDER_NAME, 30)
	return hubFolder
end

local function findBoard(name)
	if not hubFolder then
		return nil
	end
	local board = hubFolder:FindFirstChild(name)
	if not board then
		return nil
	end
	return board:FindFirstChild("BoardGui")
end

local function setBoardText(boardName, text)
	local gui = findBoard(boardName)
	if not gui then
		return
	end
	local body = gui:FindFirstChild("Body")
	if body then
		body.Text = text
	end
end

local function updateBillboards(payload)
	setBoardText("StatsBoard", string.format(
		"Wins: %d\nLosses: %d\nRank: %d",
		payload.wins or 0,
		payload.losses or 0,
		payload.rank or 0
	))
	setBoardText("ModeBoard", payload.modeLabel or "Modus: Training")

	if payload.leaderboard then
		local lines = {}
		for _, entry in payload.leaderboard do
			table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
		end
		if #lines == 0 then
			table.insert(lines, "Noch keine Einträge")
		end
		setBoardText("LeaderboardBoard", table.concat(lines, "\n"))
	end
end

local function bindArenaPrompt()
	if not hubFolder then
		return
	end
	local gate = hubFolder:FindFirstChild("ArenaGate")
	if not gate then
		return
	end
	local portal = gate:FindFirstChild("Portal")
	if not portal then
		return
	end
	local prompt = portal:FindFirstChild("EnterArenaPrompt")
	if not prompt then
		return
	end
	prompt.Triggered:Connect(function()
		Remotes.EnterArena:FireServer()
	end)
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	inHub = payload.inHub ~= false
	updateBillboards(payload)
	player:SetAttribute("InHub", inHub)
end)

task.spawn(function()
	if waitForHub() then
		bindArenaPrompt()
	end
end)

return {
	isInHub = function()
		return inHub
	end,
}
