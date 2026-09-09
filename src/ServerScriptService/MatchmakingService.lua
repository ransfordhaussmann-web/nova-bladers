local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTokens = {}

local remotes = nil
local bindables = nil
local onQueueChanged = nil

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {
			members = {},
			fillStartedAt = nil,
		}
	end
	return queues[modeId]
end

local function getModeConfig(modeId)
	return MatchmakingConfig.getMode(modeId)
end

local function removeFromMemberList(members, player)
	for index, member in members do
		if member == player then
			table.remove(members, index)
			return true
		end
	end
	return false
end

local function buildQueuePayload(modeId, player)
	local config = getModeConfig(modeId)
	local queue = getQueue(modeId)
	if not config then
		return nil
	end

	local position = 0
	for index, member in queue.members do
		if member == player then
			position = index
			break
		end
	end

	local status = "waiting"
	if MatchStateService.isBusy() then
		status = "pending"
	elseif #queue.members >= config.minPlayers then
		status = "ready"
	end

	local fillRemaining = nil
	if config.fillTimeout > 0 and queue.fillStartedAt and #queue.members >= config.minPlayers then
		local elapsed = os.clock() - queue.fillStartedAt
		fillRemaining = math.max(0, math.ceil(config.fillTimeout - elapsed))
	end

	return {
		modeId = modeId,
		modeLabel = config.label,
		count = #queue.members,
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		position = position,
		status = status,
		fillRemaining = fillRemaining,
	}
end

local function broadcastQueueUpdate(modeId)
	if not remotes then
		return
	end

	local queue = getQueue(modeId)
	for _, member in queue.members do
		if member.Parent then
			local payload = buildQueuePayload(modeId, member)
			if payload then
				remotes.QueueUpdate:FireClient(member, payload)
			end
		end
	end
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local queue = getQueue(modeId)
	queue.fillStartedAt = nil
end

local function startFillTimer(modeId)
	local config = getModeConfig(modeId)
	if not config or config.fillTimeout <= 0 then
		return
	end

	local queue = getQueue(modeId)
	if queue.fillStartedAt then
		return
	end

	queue.fillStartedAt = os.clock()
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.spawn(function()
		while token == fillTokens[modeId] do
			local currentQueue = getQueue(modeId)
			if #currentQueue.members < config.minPlayers then
				return
			end

			broadcastQueueUpdate(modeId)

			local elapsed = os.clock() - currentQueue.fillStartedAt
			if elapsed >= config.fillTimeout then
				MatchmakingService.tryStartMatch(modeId)
				return
			end

			task.wait(0.5)
		end
	end)
end

local function clearPlayerFromQueues(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = getQueue(modeId)
	removeFromMemberList(queue.members, player)

	if #queue.members < getModeConfig(modeId).minPlayers then
		cancelFillTimer(modeId)
	end

	broadcastQueueUpdate(modeId)
	if onQueueChanged then
		onQueueChanged()
	end
end

function MatchmakingService.configure(options)
	if options.remotes then
		remotes = options.remotes
	end
	if options.bindables then
		bindables = options.bindables
	end
	if options.onQueueChanged then
		onQueueChanged = options.onQueueChanged
	end
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
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

function MatchmakingService.joinQueue(player, modeId)
	local config = getModeConfig(modeId)
	if not config or not player.Parent then
		return false, "invalid_mode"
	end

	if playerQueue[player] == modeId then
		return true
	end

	MatchmakingService.leaveQueue(player)

	local queue = getQueue(modeId)
	if #queue.members >= config.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue.members, player)
	playerQueue[player] = modeId

	if #queue.members >= config.minPlayers and config.fillTimeout > 0 then
		startFillTimer(modeId)
	end

	broadcastQueueUpdate(modeId)
	if onQueueChanged then
		onQueueChanged()
	end

	if config.fillTimeout <= 0 and #queue.members >= config.minPlayers then
		MatchmakingService.tryStartMatch(modeId)
	elseif #queue.members >= config.maxPlayers then
		MatchmakingService.tryStartMatch(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	clearPlayerFromQueues(player)
end

function MatchmakingService.tryStartMatch(modeId)
	local config = getModeConfig(modeId)
	if not config then
		return
	end

	local queue = getQueue(modeId)
	if #queue.members < config.minPlayers then
		return
	end

	if MatchStateService.isBusy() then
		broadcastQueueUpdate(modeId)
		return
	end

	cancelFillTimer(modeId)

	local matchPlayers = {}
	for index = 1, math.min(#queue.members, config.maxPlayers) do
		table.insert(matchPlayers, queue.members[index])
	end

	for _, matchPlayer in matchPlayers do
		clearPlayerFromQueues(matchPlayer)
	end

	if bindables and bindables.MatchReady then
		bindables.MatchReady:Fire(matchPlayers, modeId)
	end
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setBusy(false)

	for modeId in MatchmakingConfig.MODES do
		local config = getModeConfig(modeId)
		local queue = getQueue(modeId)
		if #queue.members >= config.minPlayers then
			if config.fillTimeout > 0 and not queue.fillStartedAt then
				startFillTimer(modeId)
			else
				MatchmakingService.tryStartMatch(modeId)
			end
		else
			broadcastQueueUpdate(modeId)
		end
	end

	if onQueueChanged then
		onQueueChanged()
	end
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

return MatchmakingService
