local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local remotes
local matchReadyBindable
local getPlayerPhase
local leaveHubForArena

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local ffaFillToken = 0
local started = false

local function countQueue(modeId)
	return #queues[modeId]
end

local function queueContains(modeId, player)
	for _, queued in queues[modeId] do
		if queued == player then
			return true
		end
	end
	return false
end

local function removeFromAllQueues(player)
	for modeId, list in queues do
		for i = #list, 1, -1 do
			if list[i] == player then
				table.remove(list, i)
			end
		end
	end
	playerQueue[player] = nil
end

local function buildQueuePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local pending = MatchStateService.isArenaBusy()
	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		count = countQueue(modeId),
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		pending = pending,
		fillSeconds = modeId == "ffa" and MatchmakingConfig.FFA_FILL_TIMEOUT or nil,
	}
end

local function broadcastQueue(player)
	if remotes and remotes.QueueUpdate then
		remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	end
end

local function broadcastAllQueued()
	for player in playerQueue do
		if player.Parent then
			broadcastQueue(player)
		end
	end
end

local function popPlayers(modeId, count)
	local list = queues[modeId]
	local picked = {}
	for _ = 1, math.min(count, #list) do
		local player = table.remove(list, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(picked, player)
		end
	end
	return picked
end

local function launchMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	MatchStateService.setArenaBusy(true)
	for _, player in playerList do
		if leaveHubForArena then
			leaveHubForArena(player)
		end
	end
	matchReadyBindable:Fire({
		mode = modeId,
		players = playerList,
	})
end

local function tryStartTraining()
	if MatchStateService.isArenaBusy() then
		return
	end
	if countQueue("training") < 1 then
		return
	end
	local players = popPlayers("training", 1)
	launchMatch("training", players)
end

local function tryStartPvP()
	if MatchStateService.isArenaBusy() then
		return
	end
	if countQueue("pvp") < 2 then
		return
	end
	local players = popPlayers("pvp", 2)
	launchMatch("pvp", players)
end

local function tryStartFFA()
	if MatchStateService.isArenaBusy() then
		return
	end
	local size = countQueue("ffa")
	if size < MatchModes.ffa.minPlayers then
		return
	end

	ffaFillToken += 1
	local token = ffaFillToken
	local mode = MatchModes.ffa
	local deadline = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT

	task.spawn(function()
		while token == ffaFillToken and not MatchStateService.isArenaBusy() do
			size = countQueue("ffa")
			if size >= mode.maxPlayers then
				break
			end
			if size >= mode.minPlayers and os.clock() >= deadline then
				break
			end
			if size < mode.minPlayers then
				return
			end
			task.wait(0.25)
		end

		if token ~= ffaFillToken or MatchStateService.isArenaBusy() then
			return
		end

		size = countQueue("ffa")
		if size < mode.minPlayers then
			return
		end

		local take = math.min(size, mode.maxPlayers)
		local players = popPlayers("ffa", take)
		if #players >= mode.minPlayers then
			launchMatch("ffa", players)
		end
	end)
end

local function processQueues()
	tryStartTraining()
	tryStartPvP()
	tryStartFFA()
end

function MatchmakingService.onArenaFreed()
	MatchStateService.setArenaBusy(false)
	broadcastAllQueued()
	processQueues()
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromAllQueues(player)
	broadcastQueue(player)
	processQueues()
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end
	if getPlayerPhase and getPlayerPhase(player) ~= "hub" then
		return
	end
	if playerQueue[player] == modeId then
		broadcastQueue(player)
		return
	end

	removeFromAllQueues(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	broadcastQueue(player)
	broadcastAllQueued()
	processQueues()
end

function MatchmakingService.joinQuickMatch(player, onlineCount)
	local modeId = MatchModes.resolveQuickMatch(onlineCount or #Players:GetPlayers())
	MatchmakingService.joinQueue(player, modeId)
end

function MatchmakingService.start(deps)
	if started then
		return
	end
	started = true

	remotes = deps.remotes
	matchReadyBindable = deps.matchReadyBindable
	getPlayerPhase = deps.getPlayerPhase
	leaveHubForArena = deps.leaveHubForArena

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if modeId == "quick" then
			MatchmakingService.joinQuickMatch(player, #Players:GetPlayers())
		else
			MatchmakingService.joinQueue(player, modeId)
		end
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		if playerQueue[player] then
			removeFromAllQueues(player)
			task.defer(processQueues)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_BROADCAST_INTERVAL)
			broadcastAllQueued()
		end
	end)
end

return MatchmakingService
