local MatchmakingService = {}
MatchmakingService.__index = MatchmakingService

local function filterAlive(players)
	local alive = {}
	for _, player in players do
		if player.Parent then
			table.insert(alive, player)
		end
	end
	return alive
end

function MatchmakingService.new(config, remotes, bindables)
	local self = setmetatable({}, MatchmakingService)

	self.config = config
	self.remotes = remotes
	self.bindables = bindables
	self.arenaBusy = false
	self.queues = {}
	self.playerMode = {}

	for modeId in config.MODES do
		self.queues[modeId] = {
			players = {},
			fillToken = 0,
		}
	end

	return self
end

function MatchmakingService.setArenaBusy(busy)
	self.arenaBusy = busy
	if not busy then
		self:tryAllQueues()
	end
end

function MatchmakingService.getPlayerStatus(player)
	local modeId = self.playerMode[player]
	if not modeId then
		return nil
	end
	return self:buildStatus(player, modeId)
end

function MatchmakingService.buildStatus(player, modeId)
	local mode = self.config.MODES[modeId]
	local queue = self.queues[modeId]
	local position = 0
	for i, queuedPlayer in queue.players do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local status = "waiting"
	if self.arenaBusy and #queue.players >= mode.minPlayers then
		status = "pending"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		queued = #queue.players,
		needed = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
	}
end

function MatchmakingService.broadcastQueue(modeId)
	local queue = self.queues[modeId]
	for _, player in queue.players do
		if player.Parent then
			self.remotes.QueueUpdate:FireClient(player, self:buildStatus(player, modeId))
		end
	end
end

function MatchmakingService.removeFromQueue(player, skipNotify)
	local modeId = self.playerMode[player]
	if not modeId then
		return
	end

	local queue = self.queues[modeId]
	for i, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, i)
			break
		end
	end

	self.playerMode[player] = nil
	queue.fillToken += 1
	self:broadcastQueue(modeId)
	self:tryQueue(modeId)

	if not skipNotify and player.Parent then
		self.remotes.QueueUpdate:FireClient(player, nil)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not self.config.MODES[modeId] then
		modeId = self.config.DEFAULT_MODE
	end

	if self.playerMode[player] == modeId then
		self.remotes.QueueUpdate:FireClient(player, self:buildStatus(player, modeId))
		return
	end

	self:removeFromQueue(player, true)

	local queue = self.queues[modeId]
	table.insert(queue.players, player)
	self.playerMode[player] = modeId

	self:broadcastQueue(modeId)
	self:scheduleFillTimer(modeId)
	self:tryQueue(modeId)
end

function MatchmakingService.scheduleFillTimer(modeId)
	local mode = self.config.MODES[modeId]
	if not mode.fillTimeout then
		return
	end

	local queue = self.queues[modeId]
	queue.fillToken += 1
	local token = queue.fillToken

	task.delay(mode.fillTimeout, function()
		if token ~= queue.fillToken then
			return
		end
		if #queue.players >= mode.minPlayers then
			self:tryQueue(modeId)
		end
	end)
end

function MatchmakingService.tryAllQueues()
	for modeId in self.config.MODES do
		self:tryQueue(modeId)
	end
end

function MatchmakingService.tryQueue(modeId)
	local mode = self.config.MODES[modeId]
	local queue = self.queues[modeId]
	local alive = filterAlive(queue.players)

	if #alive < mode.minPlayers then
		return
	end

	if self.arenaBusy then
		for _, player in alive do
			if player.Parent then
				self.remotes.QueueUpdate:FireClient(player, self:buildStatus(player, modeId))
			end
		end
		return
	end

	local count = math.min(#alive, mode.maxPlayers)
	local matchPlayers = {}
	for i = 1, count do
		table.insert(matchPlayers, alive[i])
	end

	for _, player in matchPlayers do
		self:removeFromQueue(player)
	end

	self.arenaBusy = true
	self.bindables.MatchReady:Fire(matchPlayers, modeId)
end

function MatchmakingService.onMatchEnded()
	self.arenaBusy = false
	self:tryAllQueues()
end

function MatchmakingService.onPlayerRemoving(player)
	self:removeFromQueue(player)
end

return MatchmakingService
