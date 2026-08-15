local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes = RemotesSetup.ensure()

local MatchmakingQueue = {}

local queue = {}
local onMatchReady = nil
local tickRunning = false

local MODE_LABELS = {
	training = "Training",
	pvp = "1v1 PvP",
	ffa = "FFA",
}

local function getRequiredCount(modeId)
	return HubConfig.MODE_REQUIRED[modeId] or 1
end

local function getModeLabel(modeId)
	return MODE_LABELS[modeId] or modeId
end

local function countForMode(modeId)
	local count = 0
	for _, entry in queue do
		if entry.modeId == modeId then
			count += 1
		end
	end
	return count
end

local function removePlayers(playerList)
	for _, player in playerList do
		queue[player] = nil
		if player.Parent then
			Remotes.QueueState:FireClient(player, { inQueue = false })
		end
	end
end

local function broadcastState()
	local counts = {
		training = countForMode("training"),
		pvp = countForMode("pvp"),
		ffa = countForMode("ffa"),
	}

	for player, entry in queue do
		if player.Parent then
			Remotes.QueueState:FireClient(player, {
				inQueue = true,
				modeId = entry.modeId,
				modeLabel = getModeLabel(entry.modeId),
				count = counts[entry.modeId],
				required = getRequiredCount(entry.modeId),
				waitSeconds = math.floor(os.clock() - entry.joinedAt),
				maxWait = HubConfig.QUEUE.MAX_WAIT,
			})
		end
	end
end

local function collectForMode(modeId)
	local entries = {}
	for player, entry in queue do
		if entry.modeId == modeId and player.Parent then
			table.insert(entries, { player = player, joinedAt = entry.joinedAt })
		end
	end
	table.sort(entries, function(a, b)
		return a.joinedAt < b.joinedAt
	end)
	return entries
end

local function tryStartMatch()
	if not onMatchReady then
		return
	end

	local now = os.clock()
	local minWait = HubConfig.QUEUE.MIN_WAIT
	local maxWait = HubConfig.QUEUE.MAX_WAIT

	for _, modeId in { "ffa", "pvp", "training" } do
		local entries = collectForMode(modeId)
		if #entries > 0 then
			local required = getRequiredCount(modeId)
			local oldestWait = now - entries[1].joinedAt
			local canStart = #entries >= required and oldestWait >= minWait
			local timedOut = oldestWait >= maxWait

			if modeId == "ffa" and #entries >= required and (canStart or timedOut) then
				local players = {}
				for _, entry in entries do
					table.insert(players, entry.player)
				end
				removePlayers(players)
				onMatchReady(players, modeId)
				return
			end

			if modeId == "pvp" and #entries >= required and (canStart or timedOut) then
				local players = { entries[1].player, entries[2].player }
				removePlayers(players)
				onMatchReady(players, modeId)
				return
			end

			if modeId == "training" and (canStart or timedOut) then
				local players = { entries[1].player }
				removePlayers(players)
				onMatchReady(players, modeId)
				return
			end
		end
	end

	-- Downgrade: solo player waited too long in pvp queue → training
	for player, entry in queue do
		if entry.modeId == "pvp" and now - entry.joinedAt >= maxWait then
			local players = { player }
			removePlayers(players)
			onMatchReady(players, "training")
			return
		end
	end
end

local function ensureTick()
	if tickRunning then
		return
	end
	tickRunning = true
	task.spawn(function()
		while next(queue) do
			tryStartMatch()
			broadcastState()
			task.wait(HubConfig.QUEUE.TICK)
		end
		tickRunning = false
	end)
end

function MatchmakingQueue.init(callback)
	onMatchReady = callback
end

function MatchmakingQueue.join(player, modeId)
	if queue[player] then
		return
	end
	queue[player] = {
		modeId = modeId,
		joinedAt = os.clock(),
	}
	broadcastState()
	ensureTick()
end

function MatchmakingQueue.leave(player)
	if not queue[player] then
		return
	end
	queue[player] = nil
	if player.Parent then
		Remotes.QueueState:FireClient(player, { inQueue = false })
	end
	broadcastState()
end

function MatchmakingQueue.isQueued(player)
	return queue[player] ~= nil
end

function MatchmakingQueue.getPreferredMode(player)
	local entry = queue[player]
	return entry and entry.modeId
end

Players.PlayerRemoving:Connect(function(player)
	queue[player] = nil
end)

return MatchmakingQueue
