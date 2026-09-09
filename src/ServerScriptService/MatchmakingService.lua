local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function buildPayload(modeId)
	local config = getModeConfig(modeId)
	local names = {}
	for _, queuedPlayer in queues[modeId] do
		if queuedPlayer.Parent then
			table.insert(names, queuedPlayer.Name)
		end
	end

	local count = #names
	local status = "waiting"
	if count >= config.minPlayers then
		if MatchStateService.isArenaBusy() then
			status = "pending"
		else
			status = "ready"
		end
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = config.label,
		players = names,
		count = count,
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		status = status,
	}
end

local function broadcastQueueUpdate(modeId)
	local payload = buildPayload(modeId)
	for _, queuedPlayer in queues[modeId] do
		if queuedPlayer.Parent then
			Remotes.QueueUpdate:FireClient(queuedPlayer, payload)
		end
	end
end

local function clearFillTimer(modeId)
	fillTimers[modeId] = nil
end

local function startFillTimer(modeId)
	local config = getModeConfig(modeId)
	if not config.fillTimeout then
		return
	end

	local token = {}
	fillTimers[modeId] = token
	task.delay(config.fillTimeout, function()
		if fillTimers[modeId] ~= token then
			return
		end
		MatchmakingService.tryStartMatch(modeId)
	end)
end

function MatchmakingService.getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.tryStartMatch(modeId)
	local config = getModeConfig(modeId)
	if not config then
		return
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdate(modeId)
		return
	end

	local queue = queues[modeId]
	if #queue < config.minPlayers then
		return
	end

	local matchPlayers = {}
	local take = math.min(#queue, config.maxPlayers)
	for _ = 1, take do
		local nextPlayer = table.remove(queue, 1)
		if nextPlayer and nextPlayer.Parent then
			playerQueue[nextPlayer] = nil
			table.insert(matchPlayers, nextPlayer)
		end
	end

	clearFillTimer(modeId)

	for _, player in matchPlayers do
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end

	broadcastQueueUpdate(modeId)

	if #matchPlayers >= config.minPlayers then
		MatchStateService.setArenaBusy(true)
		Bindables.MatchReady:Fire(matchPlayers, modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if playerQueue[player] then
		MatchmakingService.leaveQueue(player, true)
	end

	local config = getModeConfig(modeId)
	if not config then
		return
	end

	if MatchStateService.isArenaBusy() and modeId == "training" then
		-- Training still queues; match starts when arena frees up.
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	broadcastQueueUpdate(modeId)

	if modeId == "training" then
		MatchmakingService.tryStartMatch(modeId)
	elseif modeId == "pvp" and #queues[modeId] >= config.minPlayers then
		MatchmakingService.tryStartMatch(modeId)
	elseif modeId == "ffa" then
		if #queues[modeId] >= config.maxPlayers then
			MatchmakingService.tryStartMatch(modeId)
		elseif #queues[modeId] >= config.minPlayers and not fillTimers[modeId] then
			startFillTimer(modeId)
		end
	end
end

function MatchmakingService.leaveQueue(player, silent)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	for index, queuedPlayer in queues[modeId] do
		if queuedPlayer == player then
			table.remove(queues[modeId], index)
			break
		end
	end

	if not silent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end

	local config = getModeConfig(modeId)
	if config and modeId == "ffa" and #queues[modeId] < config.minPlayers then
		clearFillTimer(modeId)
	end

	broadcastQueueUpdate(modeId)
end

function MatchmakingService.onMatchEnded()
	for modeId in MatchmakingConfig.MODES do
		local config = getModeConfig(modeId)
		if #queues[modeId] >= config.minPlayers then
			if modeId == "ffa" and not fillTimers[modeId] and #queues[modeId] < config.maxPlayers then
				startFillTimer(modeId)
			else
				MatchmakingService.tryStartMatch(modeId)
			end
		end
	end
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player, true)
end

return MatchmakingService
