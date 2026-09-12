local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}
MatchmakingService.__index = MatchmakingService

function MatchmakingService.new()
	local self = setmetatable({}, MatchmakingService)
	self.queues = {
		training = {},
		pvp = {},
		ffa = {},
	}
	self.playerMode = {}
	self.arenaBusy = false
	self.ffaTimerToken = 0
	self.onQueueUpdate = nil
	self.onMatchReady = nil
	return self
end

function MatchmakingService:setArenaBusy(busy)
	self.arenaBusy = busy
	self:_broadcastAll()
end

function MatchmakingService:isArenaBusy()
	return self.arenaBusy
end

function MatchmakingService:getPlayerMode(player)
	return self.playerMode[player]
end

function MatchmakingService:getQueueCount(modeId)
	local queue = self.queues[modeId]
	return queue and #queue or 0
end

function MatchmakingService:_removeFromQueue(player)
	local modeId = self.playerMode[player]
	if not modeId then
		return
	end

	local queue = self.queues[modeId]
	if queue then
		for i, queuedPlayer in queue do
			if queuedPlayer == player then
				table.remove(queue, i)
				break
			end
		end
	end
	self.playerMode[player] = nil
end

function MatchmakingService:_playerNames(queue)
	local names = {}
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			table.insert(names, queuedPlayer.Name)
		end
	end
	return names
end

function MatchmakingService:getPlayerPayload(player)
	return self:_buildPlayerPayload(player)
end

function MatchmakingService:_buildPlayerPayload(player)
	local modeId = self.playerMode[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchmakingConfig.MODES[modeId]
	local queue = self.queues[modeId]
	local count = queue and #queue or 0
	local status = "waiting"
	if self.arenaBusy then
		status = "pending"
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		queueCount = count,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		playerNames = queue and self:_playerNames(queue) or {},
		arenaBusy = self.arenaBusy,
		status = status,
	}
end

function MatchmakingService:_broadcastAll()
	if not self.onQueueUpdate then
		return
	end
	for modeId, queue in self.queues do
		for _, queuedPlayer in queue do
			if queuedPlayer.Parent then
				self.onQueueUpdate(queuedPlayer, self:_buildPlayerPayload(queuedPlayer))
			end
		end
	end
end

function MatchmakingService:_broadcastMode(modeId)
	if not self.onQueueUpdate then
		return
	end
	local queue = self.queues[modeId]
	if not queue then
		return
	end
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			self.onQueueUpdate(queuedPlayer, self:_buildPlayerPayload(queuedPlayer))
		end
	end
end

function MatchmakingService:leaveQueue(player)
	if not self.playerMode[player] then
		return
	end
	local modeId = self.playerMode[player]
	self:_removeFromQueue(player)
	if self.onQueueUpdate then
		self.onQueueUpdate(player, { inQueue = false })
	end
	self:_broadcastMode(modeId)
end

function MatchmakingService:joinQueue(player, modeId)
	local mode = MatchmakingConfig.MODES[modeId]
	if not mode then
		return false, "invalid_mode"
	end

	self:leaveQueue(player)

	local queue = self.queues[modeId]
	table.insert(queue, player)
	self.playerMode[player] = modeId
	self:_broadcastMode(modeId)

	if modeId == "ffa" and #queue >= mode.minPlayers then
		self:_scheduleFfaFill(modeId)
	end

	self:_tryStartMatch(modeId)
	return true
end

function MatchmakingService:_scheduleFfaFill(modeId)
	self.ffaTimerToken += 1
	local token = self.ffaTimerToken
	local mode = MatchmakingConfig.MODES[modeId]
	local timeout = mode.fillTimeout or MatchmakingConfig.FFA_FILL_TIMEOUT

	task.delay(timeout, function()
		if token ~= self.ffaTimerToken then
			return
		end
		self:_tryStartMatch(modeId, true)
	end)
end

function MatchmakingService:_popPlayers(modeId, count)
	local queue = self.queues[modeId]
	local players = {}
	for _ = 1, count do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(players, player)
			self.playerMode[player] = nil
		end
	end
	return players
end

function MatchmakingService:_tryStartMatch(modeId, forceFfa)
	local mode = MatchmakingConfig.MODES[modeId]
	if not mode then
		return
	end

	local queue = self.queues[modeId]
	local count = #queue

	if count < mode.minPlayers then
		return
	end

	if self.arenaBusy then
		self:_broadcastMode(modeId)
		return
	end

	local startCount = mode.maxPlayers
	if modeId == "ffa" then
		if not forceFfa and count < mode.maxPlayers then
			return
		end
		startCount = math.min(count, mode.maxPlayers)
	else
		startCount = mode.minPlayers
	end

	if count < startCount then
		return
	end

	if modeId == "ffa" then
		self.ffaTimerToken += 1
	end

	local players = self:_popPlayers(modeId, startCount)
	if #players < mode.minPlayers then
		for _, player in players do
			table.insert(queue, player)
			self.playerMode[player] = modeId
		end
		return
	end

	self.arenaBusy = true
	self:_broadcastAll()

	if self.onMatchReady then
		self.onMatchReady(players, modeId)
	end
end

function MatchmakingService:onPlayerRemoving(player)
	self:leaveQueue(player)
end

return MatchmakingService
