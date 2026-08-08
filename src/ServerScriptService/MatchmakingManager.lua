--[[
	Matchmaking queue — players join, wait for opponents, then start a match.
	Solo players get training after SOLO_TIMEOUT; 2+ triggers PvP/FFA after GATHER_DELAY.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local Remotes = RemotesSetup.ensure()

local MatchmakingManager = {}

local CONFIG = {
	GATHER_DELAY = 3,
	SOLO_TIMEOUT = 18,
	TICK = 0.5,
}

local queue = {}
local queueSet = {}
local gatherToken = 0
local gatherThread = nil
local callbacks = {}
local matchActive = false

local function getModeForCount(count)
	if count >= 3 then
		return "ffa", "Modus: FFA"
	elseif count >= 2 then
		return "pvp", "Modus: 1v1 PvP"
	end
	return "training", "Modus: Training"
end

local function pruneQueue()
	local i = 1
	while i <= #queue do
		local player = queue[i]
		if not player.Parent or queueSet[player] ~= true then
			queueSet[player] = nil
			table.remove(queue, i)
		else
			i += 1
		end
	end
end

local function buildStatus(player)
	pruneQueue()
	local count = #queue
	local mode, modeLabel = getModeForCount(count)
	local position = nil
	for i, p in queue do
		if p == player then
			position = i
			break
		end
	end
	return {
		inQueue = position ~= nil,
		position = position,
		count = count,
		mode = mode,
		modeLabel = modeLabel,
		matchActive = matchActive,
	}
end

local function broadcastStatus(extra)
	pruneQueue()
	local count = #queue
	local mode, modeLabel = getModeForCount(count)
	local payload = {
		count = count,
		mode = mode,
		modeLabel = modeLabel,
		gatherDelay = extra and extra.gatherDelay,
		soloWait = extra and extra.soloWait,
		matchActive = matchActive,
	}
	for i, player in queue do
		if player.Parent then
			Remotes.QueueStatus:FireClient(player, {
				inQueue = true,
				position = i,
				count = count,
				mode = mode,
				modeLabel = modeLabel,
				gatherDelay = payload.gatherDelay,
				soloWait = payload.soloWait,
				matchActive = matchActive,
			})
		end
	end
end

local function notifyLeft(player)
	if player.Parent then
		Remotes.QueueStatus:FireClient(player, {
			inQueue = false,
			matchActive = matchActive,
		})
	end
end

local function popMatch()
	pruneQueue()
	if #queue == 0 then
		return
	end

	local players = table.clone(queue)
	queue = {}
	queueSet = {}
	gatherToken += 1

	for _, player in players do
		notifyLeft(player)
	end

	if callbacks.onMatchReady then
		callbacks.onMatchReady(players)
	end
end

local function startGatherLoop()
	gatherToken += 1
	local token = gatherToken
	local soloDeadline = os.clock() + CONFIG.SOLO_TIMEOUT

	if gatherThread then
		task.cancel(gatherThread)
	end

	gatherThread = task.spawn(function()
		local gatherStarted = false
		local gatherEnd = 0

		while token == gatherToken and #queue > 0 and not matchActive do
			pruneQueue()
			local count = #queue
			if count == 0 then
				break
			end

			if count >= 2 then
				if not gatherStarted then
					gatherStarted = true
					gatherEnd = os.clock() + CONFIG.GATHER_DELAY
					broadcastStatus({ gatherDelay = CONFIG.GATHER_DELAY })
				end
				local remaining = math.ceil(gatherEnd - os.clock())
				if remaining <= 0 then
					popMatch()
					return
				end
				broadcastStatus({ gatherDelay = remaining })
			elseif count == 1 then
				gatherStarted = false
				local soloRemaining = math.ceil(soloDeadline - os.clock())
				if soloRemaining <= 0 then
					popMatch()
					return
				end
				broadcastStatus({ soloWait = soloRemaining })
			end

			task.wait(CONFIG.TICK)
		end
	end)
end

function MatchmakingManager.register(handlers)
	callbacks = handlers or {}
end

function MatchmakingManager.setMatchActive(active)
	matchActive = active == true
	if matchActive then
		gatherToken += 1
	end
end

function MatchmakingManager.isInQueue(player)
	return queueSet[player] == true
end

function MatchmakingManager.join(player)
	if matchActive then
		return false, "match_active"
	end
	if queueSet[player] then
		return true
	end

	table.insert(queue, player)
	queueSet[player] = true
	broadcastStatus()
	startGatherLoop()
	return true
end

function MatchmakingManager.leave(player)
	if not queueSet[player] then
		return
	end

	for i, p in queue do
		if p == player then
			table.remove(queue, i)
			break
		end
	end
	queueSet[player] = nil
	notifyLeft(player)
	broadcastStatus()

	if #queue == 0 then
		gatherToken += 1
	end
end

function MatchmakingManager.removePlayer(player)
	MatchmakingManager.leave(player)
end

function MatchmakingManager.getStatus(player)
	return buildStatus(player)
end

Players.PlayerRemoving:Connect(function(player)
	MatchmakingManager.removePlayer(player)
end)

return MatchmakingManager
