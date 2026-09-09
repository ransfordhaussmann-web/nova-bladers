local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}
MatchmakingService.__index = MatchmakingService

function MatchmakingService.new(options)
	local self = setmetatable({}, MatchmakingService)
	self.queues = {
		training = {},
		pvp = {},
		ffa = {},
	}
	self.playerQueue = {}
	self.onMatchReady = options.onMatchReady
	self.onQueueUpdate = options.onQueueUpdate
	return self
end

function MatchmakingService:getPlayerMode(player)
	local entry = self.playerQueue[player]
	return entry and entry.modeId
end

function MatchmakingService:isQueued(player)
	return self.playerQueue[player] ~= nil
end

function MatchmakingService:getQueueSnapshot(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return nil
	end
	return {
		modeId = modeId,
		modeLabel = mode.label,
		current = #self.queues[modeId],
		needed = mode.minPlayers,
	}
end

function MatchmakingService:sendUpdate(player)
	local modeId = self:getPlayerMode(player)
	if not modeId then
		self.onQueueUpdate(player, { inQueue = false })
		return
	end

	local snapshot = self:getQueueSnapshot(modeId)
	snapshot.inQueue = true
	snapshot.position = self:_getPosition(player, modeId)
	self.onQueueUpdate(player, snapshot)
end

function MatchmakingService:_getPosition(player, modeId)
	local queue = self.queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			return index
		end
	end
	return #queue
end

function MatchmakingService:_broadcastMode(modeId)
	for _, queuedPlayer in self.queues[modeId] do
		if queuedPlayer.Parent then
			self:sendUpdate(queuedPlayer)
		end
	end
end

function MatchmakingService:_removeFromQueue(player)
	local entry = self.playerQueue[player]
	if not entry then
		return nil
	end

	local modeId = entry.modeId
	local queue = self.queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	self.playerQueue[player] = nil
	return modeId
end

function MatchmakingService:leaveQueue(player)
	local modeId = self:_removeFromQueue(player)
	if modeId then
		self:sendUpdate(player)
		self:_broadcastMode(modeId)
	end
end

function MatchmakingService:joinQueue(player, modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return false
	end

	self:leaveQueue(player)
	table.insert(self.queues[modeId], player)
	self.playerQueue[player] = {
		modeId = modeId,
		joinedAt = os.clock(),
	}

	self:sendUpdate(player)
	self:_broadcastMode(modeId)
	self:_tryStartMatch(modeId)
	return true
end

function MatchmakingService:_popPlayers(modeId, count)
	local players = {}
	for _ = 1, count do
		local nextPlayer = table.remove(self.queues[modeId], 1)
		if not nextPlayer then
			break
		end
		self.playerQueue[nextPlayer] = nil
		table.insert(players, nextPlayer)
	end
	return players
end

function MatchmakingService:_tryStartMatch(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = self.queues[modeId]

	while #queue >= mode.minPlayers do
		local takeCount = math.min(mode.maxPlayers, #queue)
		if takeCount < mode.minPlayers then
			break
		end

		local players = self:_popPlayers(modeId, takeCount)
		if #players < mode.minPlayers then
			break
		end

		self.onMatchReady(players, modeId)
	end

	self:_broadcastMode(modeId)
end

function MatchmakingService:clearPlayer(player)
	local modeId = self:_removeFromQueue(player)
	if modeId then
		self:_broadcastMode(modeId)
	end
end

return MatchmakingService
