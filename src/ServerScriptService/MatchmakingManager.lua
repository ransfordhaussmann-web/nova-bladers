--[[
	MatchmakingManager — per-mode queues (Training / 1v1 / FFA).
	Starts a match when the required player count is reached.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

local MODE_REQUIREMENTS = {
	training = 1,
	pvp = 2,
	ffa = 3,
}

local MODE_LABELS = {
	training = "Training",
	pvp = "1v1 PvP",
	ffa = "FFA",
}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}

local function isMatchIdle()
	local bindable = Bindables:FindFirstChild("IsMatchIdle")
	if bindable and bindable:IsA("BindableFunction") then
		return bindable:Invoke()
	end
	return true
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end
	playerQueue[player] = nil
end

local function buildQueueSnapshot()
	local counts = {}
	for modeId, queue in queues do
		counts[modeId] = #queue
	end
	return {
		counts = counts,
		requirements = MODE_REQUIREMENTS,
		labels = MODE_LABELS,
	}
end

local function broadcastQueueUpdate()
	for _, player in Players:GetPlayers() do
		local payload = buildQueueSnapshot()
		payload.yourMode = playerQueue[player]
		Remotes.MatchQueueUpdate:FireClient(player, payload)
	end
end

local function pullPlayers(modeId)
	local queue = queues[modeId]
	local needed = MODE_REQUIREMENTS[modeId]
	if #queue < needed then
		return nil
	end

	local count = if modeId == "ffa" then #queue else needed
	local matched = {}

	for _ = 1, count do
		local queuedPlayer = table.remove(queue, 1)
		if queuedPlayer and queuedPlayer.Parent then
			playerQueue[queuedPlayer] = nil
			table.insert(matched, queuedPlayer)
		end
	end

	if #matched >= needed then
		return matched
	end
	return nil
end

local function tryStartMatches()
	if not isMatchIdle() then
		return
	end

	for _, modeId in { "training", "pvp", "ffa" } do
		local matched = pullPlayers(modeId)
		if matched and #matched >= MODE_REQUIREMENTS[modeId] then
			for _, player in matched do
				HubService.enterArena(player)
			end
			Bindables.StartQueuedMatch:Fire(matched, modeId)
			broadcastQueueUpdate()
			return
		end
	end
end

local MatchmakingManager = {}

function MatchmakingManager.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MODE_REQUIREMENTS[modeId] then
		return false, "invalid_mode"
	end
	if not isMatchIdle() then
		return false, "match_active"
	end
	if HubService.getPhase(player) ~= "hub" then
		return false, "not_in_hub"
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	broadcastQueueUpdate()
	tryStartMatches()
	return true
end

function MatchmakingManager.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end
	removeFromQueue(player)
	broadcastQueueUpdate()
	return true
end

function MatchmakingManager.onPlayerRemoving(player)
	removeFromQueue(player)
end

function MatchmakingManager.sendUpdate(player)
	if not player.Parent then
		return
	end
	local payload = buildQueueSnapshot()
	payload.yourMode = playerQueue[player]
	Remotes.MatchQueueUpdate:FireClient(player, payload)
end

function MatchmakingManager.init()
	Remotes.MatchQueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingManager.joinQueue(player, modeId)
	end)

	Remotes.MatchQueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingManager.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingManager.onPlayerRemoving(player)
	end)
end

return MatchmakingManager
