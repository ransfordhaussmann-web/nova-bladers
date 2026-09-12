local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}
MatchmakingService.__index = MatchmakingService

local singleton = nil

function MatchmakingService.ensure(remotes, bindables)
	if not singleton then
		singleton = MatchmakingService.new(remotes, bindables)
	end
	return singleton
end

function MatchmakingService.get()
	return singleton
end

local function modeOrder()
	return { "training", "pvp", "ffa" }
end

function MatchmakingService.new(remotes, bindables)
	local self = setmetatable({}, MatchmakingService)
	self.remotes = remotes
	self.bindables = bindables
	self.queues = {
		training = {},
		pvp = {},
		ffa = {},
	}
	self.playerEntry = {}
	self.arenaBusy = false
	self.ffaFillToken = 0
	self.ffaFillReady = false
	self.startToken = 0
	return self
end

function MatchmakingService:setArenaBusy(busy)
	self.arenaBusy = busy
	if not busy then
		self:tryStartMatches()
	end
end

function MatchmakingService:getPlayerEntry(player)
	return self.playerEntry[player]
end

function MatchmakingService:isInQueue(player)
	return self.playerEntry[player] ~= nil
end

function MatchmakingService:_removeFromQueueList(player, modeId)
	local queue = self.queues[modeId]
	if not queue then
		return
	end
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end
end

function MatchmakingService:_buildQueuePayload(player, entry)
	local mode = MatchmakingConfig.getMode(entry.modeId)
	local queue = self.queues[entry.modeId] or {}
	local payload = {
		inQueue = true,
		mode = entry.modeId,
		modeLabel = mode and mode.label or entry.modeId,
		status = self.arenaBusy and "pending" or "waiting",
		players = {
			count = #queue,
			required = mode and mode.minPlayers or 1,
			max = mode and mode.maxPlayers or 1,
		},
		fillCountdown = entry.fillCountdown,
	}
	return payload
end

function MatchmakingService:_broadcastQueue(player, entry)
	if player.Parent then
		self.remotes.QueueUpdate:FireClient(player, self:_buildQueuePayload(player, entry))
	end
end

function MatchmakingService:_broadcastAllInMode(modeId)
	for _, queuedPlayer in self.queues[modeId] do
		local entry = self.playerEntry[queuedPlayer]
		if entry then
			self:_broadcastQueue(queuedPlayer, entry)
		end
	end
end

function MatchmakingService:_clearPlayer(player)
	local entry = self.playerEntry[player]
	if not entry then
		return
	end
	self:_removeFromQueueList(player, entry.modeId)
	self.playerEntry[player] = nil
	if player.Parent then
		self.remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

function MatchmakingService:leaveQueue(player)
	if not self.playerEntry[player] then
		return
	end
	local modeId = self.playerEntry[player].modeId
	self:_clearPlayer(player)
	self:_broadcastAllInMode(modeId)
	self:_cancelFfaFill()
	self:tryStartMatches()
end

function MatchmakingService:joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return false, "invalid_mode"
	end
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return false, "invalid_mode"
	end
	if self.playerEntry[player] then
		self:leaveQueue(player)
	end

	table.insert(self.queues[modeId], player)
	self.playerEntry[player] = {
		modeId = modeId,
		joinedAt = os.clock(),
		fillCountdown = nil,
	}
	self:_broadcastAllInMode(modeId)
	self:tryStartMatches()
	return true
end

function MatchmakingService:onPlayerRemoving(player)
	self:_clearPlayer(player)
end

function MatchmakingService:_cancelFfaFill()
	self.ffaFillToken += 1
	self.ffaFillReady = false
	for _, entry in self.playerEntry do
		entry.fillCountdown = nil
	end
end

function MatchmakingService:_startFfaFillTimer()
	self.ffaFillToken += 1
	local token = self.ffaFillToken
	local timeout = MatchmakingConfig.FFA_FILL_TIMEOUT

	task.spawn(function()
		local remaining = timeout
		while remaining > 0 do
			if token ~= self.ffaFillToken then
				return
			end
			local queue = self.queues.ffa
			if #queue < MatchmakingConfig.MODES.ffa.minPlayers then
				return
			end
			if #queue >= MatchmakingConfig.MODES.ffa.maxPlayers then
				return
			end

			for _, queuedPlayer in queue do
				local entry = self.playerEntry[queuedPlayer]
				if entry then
					entry.fillCountdown = remaining
					self:_broadcastQueue(queuedPlayer, entry)
				end
			end

			task.wait(1)
			remaining -= 1
		end

		if token ~= self.ffaFillToken then
			return
		end
		for _, entry in self.playerEntry do
			entry.fillCountdown = nil
		end
		self.ffaFillReady = true
		self:_broadcastAllInMode("ffa")
		self:tryStartMatches()
	end)
end

function MatchmakingService:_canStartMode(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = self.queues[modeId]
	if not mode or #queue < mode.minPlayers then
		return false
	end
	if modeId == "ffa" then
		if #queue >= mode.maxPlayers then
			return true
		end
		if #queue >= mode.minPlayers then
			return self.ffaFillReady
		end
		return false
	end
	return true
end

function MatchmakingService:_popPlayers(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = self.queues[modeId]
	local count = math.min(#queue, mode.maxPlayers)
	local players = {}
	for i = 1, count do
		local queuedPlayer = queue[1]
		table.remove(queue, 1)
		table.insert(players, queuedPlayer)
		self.playerEntry[queuedPlayer] = nil
		if queuedPlayer.Parent then
			self.remotes.QueueUpdate:FireClient(queuedPlayer, { inQueue = false, matchStarting = true })
		end
	end
	return players
end

function MatchmakingService:_launchMatch(modeId, players)
	self.startToken += 1
	local token = self.startToken
	self:setArenaBusy(true)

	task.delay(MatchmakingConfig.START_DELAY, function()
		if token ~= self.startToken then
			return
		end

		local validPlayers = {}
		for _, player in players do
			if player.Parent then
				table.insert(validPlayers, player)
			end
		end

		local mode = MatchmakingConfig.getMode(modeId)
		if #validPlayers < mode.minPlayers then
			for _, player in validPlayers do
				self:joinQueue(player, modeId)
			end
			self:setArenaBusy(false)
			return
		end

		self.bindables.MatchReady:Fire({
			mode = modeId,
			players = validPlayers,
		})
	end)
end

function MatchmakingService:tryStartMatches()
	if self.arenaBusy then
		for _, modeId in modeOrder() do
			self:_broadcastAllInMode(modeId)
		end
		return
	end

	for _, modeId in modeOrder() do
		local queue = self.queues[modeId]
		local mode = MatchmakingConfig.getMode(modeId)

		if modeId == "ffa" and #queue >= mode.minPlayers and #queue < mode.maxPlayers then
			local hasTimer = false
			for _, queuedPlayer in queue do
				if self.playerEntry[queuedPlayer] and self.playerEntry[queuedPlayer].fillCountdown then
					hasTimer = true
					break
				end
			end
			if not hasTimer then
				self:_startFfaFillTimer()
			end
		end

		if self:_canStartMode(modeId) then
			local players = self:_popPlayers(modeId)
			self:_cancelFfaFill()
			self:_launchMatch(modeId, players)
			return
		end
	end
end

function MatchmakingService:removePlayersFromQueue(players)
	for _, player in players do
		self:_clearPlayer(player)
	end
end

return MatchmakingService
