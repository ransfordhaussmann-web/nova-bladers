local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}
MatchmakingService.__index = MatchmakingService

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

function MatchmakingService.new(callbacks)
	local self = setmetatable({
		_callbacks = callbacks,
		_queues = {},
		_playerQueue = {},
		_pendingMatch = nil,
		_pendingPlayers = {},
	}, MatchmakingService)

	for modeId in MatchmakingConfig.MODES do
		self._queues[modeId] = {
			players = {},
			fillDeadline = nil,
		}
	end

	return self
end

function MatchmakingService:_playerIndex(queue, player)
	for i, queued in queue.players do
		if queued == player then
			return i
		end
	end
	return nil
end

function MatchmakingService:_clearPending()
	self._pendingMatch = nil
	self._pendingPlayers = {}
end

function MatchmakingService:_removeFromQueue(player)
	local modeId = self._playerQueue[player]
	if not modeId then
		return
	end

	local queue = self._queues[modeId]
	local index = self:_playerIndex(queue, player)
	if index then
		table.remove(queue.players, index)
	end

	if #queue.players == 0 then
		queue.fillDeadline = nil
	end

	self._playerQueue[player] = nil
	self:_notifyPlayer(player)
end

function MatchmakingService:_notifyPlayer(player)
	if not player.Parent then
		return
	end
	local payload = self:getPlayerState(player)
	if self._callbacks.onQueueUpdate then
		self._callbacks.onQueueUpdate(player, payload)
	end
end

function MatchmakingService:_notifyQueue(modeId)
	local queue = self._queues[modeId]
	for _, player in queue.players do
		self:_notifyPlayer(player)
	end
end

function MatchmakingService:_notifyPending()
	if not self._pendingMatch then
		return
	end
	for _, player in self._pendingMatch.players do
		self:_notifyPlayer(player)
	end
end

function MatchmakingService:getPlayerState(player)
	if self._pendingPlayers[player] and self._pendingMatch then
		local mode = getMode(self._pendingMatch.mode)
		return {
			inQueue = true,
			modeId = self._pendingMatch.mode,
			modeLabel = mode.label,
			players = #self._pendingMatch.players,
			minPlayers = mode.minPlayers,
			maxPlayers = mode.maxPlayers,
			pending = true,
		}
	end

	local modeId = self._playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = getMode(modeId)
	local queue = self._queues[modeId]
	local secondsLeft = nil
	if queue.fillDeadline then
		secondsLeft = math.max(0, math.ceil(queue.fillDeadline - os.clock()))
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		players = #queue.players,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = false,
		secondsLeft = secondsLeft,
	}
end

function MatchmakingService:leaveQueue(player)
	if self._pendingPlayers[player] then
		self:_removeFromPending(player)
		return
	end
	if not self._playerQueue[player] then
		return
	end
	local modeId = self._playerQueue[player]
	self:_removeFromQueue(player)
	self:_notifyQueue(modeId)
end

function MatchmakingService:_removeFromPending(player)
	if not self._pendingMatch then
		return
	end

	for i, queued in self._pendingMatch.players do
		if queued == player then
			table.remove(self._pendingMatch.players, i)
			break
		end
	end
	self._pendingPlayers[player] = nil
	self:_notifyPlayer(player)

	local mode = getMode(self._pendingMatch.mode)
	if #self._pendingMatch.players < mode.minPlayers then
		local modeId = self._pendingMatch.mode
		local remaining = self._pendingMatch.players
		self:_clearPending()
		for _, queued in remaining do
			self:joinQueue(queued, modeId)
		end
	else
		self:_notifyPending()
	end
end

function MatchmakingService:joinQueue(player, modeId)
	if self._pendingPlayers[player] then
		return false
	end

	local mode = getMode(modeId)
	if not mode then
		return false
	end

	if self._playerQueue[player] == modeId then
		return true
	end

	self:leaveQueue(player)

	local queue = self._queues[modeId]
	table.insert(queue.players, player)
	self._playerQueue[player] = modeId

	if mode.fillTimeout and #queue.players >= mode.minPlayers and not queue.fillDeadline then
		queue.fillDeadline = os.clock() + mode.fillTimeout
	end

	self:_notifyQueue(modeId)
	self:_tryStartMatch(modeId)
	return true
end

function MatchmakingService:_extractPlayers(modeId)
	local mode = getMode(modeId)
	local queue = self._queues[modeId]
	local count = math.min(#queue.players, mode.maxPlayers)
	local players = {}

	for i = 1, count do
		table.insert(players, queue.players[i])
	end

	for _, player in players do
		local index = self:_playerIndex(queue, player)
		if index then
			table.remove(queue.players, index)
		end
		self._playerQueue[player] = nil
	end

	if #queue.players == 0 then
		queue.fillDeadline = nil
	end

	return players
end

function MatchmakingService:_startMatch(payload)
	if self._callbacks.isArenaBusy and self._callbacks.isArenaBusy() then
		self._pendingMatch = payload
		for _, player in payload.players do
			self._pendingPlayers[player] = true
		end
		self:_notifyPending()
		return
	end

	self:_clearPending()
	if self._callbacks.onMatchReady then
		self._callbacks.onMatchReady(payload)
	end
end

function MatchmakingService:_tryStartMatch(modeId)
	local mode = getMode(modeId)
	local queue = self._queues[modeId]
	local count = #queue.players

	if count < mode.minPlayers then
		return
	end

	if count < mode.maxPlayers and queue.fillDeadline and os.clock() < queue.fillDeadline then
		return
	end

	local players = self:_extractPlayers(modeId)
	if #players < mode.minPlayers then
		return
	end

	self:_startMatch({
		players = players,
		mode = modeId,
	})
end

function MatchmakingService:tick()
	for modeId, queue in self._queues do
		local mode = getMode(modeId)
		if mode.fillTimeout and queue.fillDeadline and #queue.players >= mode.minPlayers then
			if os.clock() >= queue.fillDeadline then
				self:_tryStartMatch(modeId)
			else
				self:_notifyQueue(modeId)
			end
		end
	end

	if self._pendingMatch and self._callbacks.isArenaBusy and not self._callbacks.isArenaBusy() then
		local payload = self._pendingMatch
		self:_clearPending()
		if self._callbacks.onMatchReady then
			self._callbacks.onMatchReady(payload)
		end
	end
end

function MatchmakingService:onMatchEnded()
	if not self._pendingMatch then
		return
	end
	if self._callbacks.isArenaBusy and self._callbacks.isArenaBusy() then
		return
	end

	local payload = self._pendingMatch
	self:_clearPending()
	if self._callbacks.onMatchReady then
		self._callbacks.onMatchReady(payload)
	end
end

function MatchmakingService:onPlayerRemoving(player)
	self:leaveQueue(player)
end

return MatchmakingService
