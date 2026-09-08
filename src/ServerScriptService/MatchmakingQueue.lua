local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes = RemotesSetup.ensure()

local MatchmakingQueue = {}

local queues = {}
local playerQueue = {}
local onReadyCallback = nil
local popTokens = {}

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = { entries = {} }
	end
	return queues[modeId]
end

local function getEffectiveMode(modeId, count)
	if modeId == MatchmakingConfig.QUICK_MATCH_MODE or modeId == "quick" then
		if count >= 3 then
			return "ffa"
		elseif count == 2 then
			return "pvp"
		end
		return "training"
	end

	local config = getModeConfig(modeId)
	if config and config.downgradeTo and count < config.minPlayers and count >= (config.downgradeMin or 2) then
		return config.downgradeTo
	end
	return modeId
end

local function buildPayload(modeId)
	local queue = ensureQueue(modeId)
	local config = getModeConfig(modeId)
	local count = #queue.entries
	local oldestWait = 0

	if count > 0 then
		oldestWait = os.clock() - queue.entries[1].joinedAt
	end

	local minPlayers = config and config.minPlayers or 1
	local maxWait = config and config.maxWait or 30
	local timeLeft = math.max(0, math.ceil(maxWait - oldestWait))

	return {
		modeId = modeId,
		modeLabel = config and config.label or modeId,
		playersInQueue = count,
		minPlayers = minPlayers,
		maxWait = maxWait,
		timeLeft = timeLeft,
		ready = count >= minPlayers,
		inQueue = count > 0,
		effectiveMode = getEffectiveMode(modeId, count),
	}
end

local function broadcastQueue(modeId)
	local payload = buildPayload(modeId)
	for _, entry in ensureQueue(modeId).entries do
		if entry.player.Parent then
			Remotes.MatchmakingUpdate:FireClient(entry.player, payload)
		end
	end
end

local function broadcastAll()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = ensureQueue(modeId)
	for i, entry in queue.entries do
		if entry.player == player then
			table.remove(queue.entries, i)
			break
		end
	end

	playerQueue[player] = nil
	popTokens[modeId] = (popTokens[modeId] or 0) + 1
	broadcastQueue(modeId)
end

function MatchmakingQueue.leave(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
	Remotes.MatchmakingUpdate:FireClient(player, { modeId = nil, inQueue = false })
end

local function popQueue(modeId, token)
	local queue = ensureQueue(modeId)
	if #queue.entries == 0 then
		return
	end
	if token and popTokens[modeId] ~= token then
		return
	end

	local players = {}
	for _, entry in queue.entries do
		if entry.player.Parent then
			table.insert(players, entry.player)
		end
	end

	for _, player in players do
		playerQueue[player] = nil
	end
	queue.entries = {}
	popTokens[modeId] = (popTokens[modeId] or 0) + 1

	if #players == 0 or not onReadyCallback then
		return
	end

	local effectiveMode = getEffectiveMode(modeId, #players)
	task.delay(MatchmakingConfig.GATHER_BUFFER, function()
		onReadyCallback(players, effectiveMode)
	end)
end

local function schedulePop(modeId)
	popTokens[modeId] = (popTokens[modeId] or 0) + 1
	local token = popTokens[modeId]
	local config = getModeConfig(modeId)
	if not config then
		return
	end

	task.spawn(function()
		while playerQueue and popTokens[modeId] == token do
			local queue = ensureQueue(modeId)
			local count = #queue.entries
			if count == 0 then
				return
			end

			local oldestWait = os.clock() - queue.entries[1].joinedAt
			local ready = count >= config.minPlayers
			local timedOut = oldestWait >= config.maxWait
			local instantPop = modeId == "quick" and count >= 3

			if instantPop or ready or timedOut then
				if timedOut and config.downgradeTo and count >= (config.downgradeMin or 2) then
					popQueue(modeId, token)
					return
				elseif ready then
					popQueue(modeId, token)
					return
				elseif config.minPlayers == 1 and count >= 1 and timedOut then
					popQueue(modeId, token)
					return
				end
			end

			broadcastQueue(modeId)
			task.wait(1)
		end
	end)
end

function MatchmakingQueue.join(player, modeId)
	if playerQueue[player] == modeId then
		return
	end

	MatchmakingQueue.leave(player)

	local queue = ensureQueue(modeId)
	table.insert(queue.entries, { player = player, joinedAt = os.clock() })
	playerQueue[player] = modeId

	broadcastQueue(modeId)
	schedulePop(modeId)
end

function MatchmakingQueue.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingQueue.getQueueMode(player)
	return playerQueue[player]
end

function MatchmakingQueue.onReady(callback)
	onReadyCallback = callback
end

function MatchmakingQueue.init()
	Players.PlayerRemoving:Connect(function(player)
		MatchmakingQueue.leave(player)
	end)
end

return MatchmakingQueue
