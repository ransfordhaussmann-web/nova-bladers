--[[
	MatchmakingService — queue players from the hub portal and start matches
	when enough players are ready (Training / 1v1 / FFA).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queue = {}
local queueIndex = {}
local gatherDeadline = nil
local gatherToken = 0
local tickTask = nil

local remotes = nil
local onMatchReady = nil
local canStartMatch = nil
local getPlayerPhase = nil
local initialized = false
local pendingJoins = {}

local MODE_LABELS = {
	training = "Training",
	pvp = "1v1 PvP",
	ffa = "FFA",
}

local function getModeFromCount(count)
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function isQueued(player)
	return queueIndex[player] ~= nil
end

local function removeFromQueue(player)
	local idx = queueIndex[player]
	if not idx then
		return false
	end

	table.remove(queue, idx)
	queueIndex[player] = nil
	for i = idx, #queue do
		queueIndex[queue[i]] = i
	end

	if #queue == 0 then
		gatherDeadline = nil
		gatherToken += 1
	end

	return true
end

local function drainQueue()
	local players = table.clone(queue)
	queue = {}
	table.clear(queueIndex)
	gatherDeadline = nil
	gatherToken += 1
	return players
end

local function getSecondsLeft()
	if not gatherDeadline then
		return nil
	end
	return math.max(0, math.ceil(gatherDeadline - os.clock()))
end

local function buildPlayerSnapshot()
	local names = {}
	for _, player in queue do
		if player.Parent then
			table.insert(names, player.DisplayName)
		end
	end
	return names
end

local function buildStateFor(player)
	local count = #queue
	local mode = getModeFromCount(count)
	local idx = queueIndex[player]

	return {
		inQueue = idx ~= nil,
		position = idx,
		queueSize = count,
		mode = mode,
		modeLabel = MODE_LABELS[mode] or mode,
		secondsLeft = getSecondsLeft(),
		players = buildPlayerSnapshot(),
	}
end

local function broadcastState()
	if not remotes or not remotes.QueueState then
		return
	end

	for _, player in queue do
		if player.Parent then
			remotes.QueueState:FireClient(player, buildStateFor(player))
		end
	end
end

local function refreshGatherDeadline()
	local count = #queue
	local now = os.clock()

	if count == 0 then
		gatherDeadline = nil
		return
	end

	if count >= 3 then
		gatherDeadline = math.min(gatherDeadline or (now + MatchmakingConfig.FFA_READY_DELAY), now + MatchmakingConfig.FFA_READY_DELAY)
	elseif count == 2 then
		gatherDeadline = math.min(gatherDeadline or (now + MatchmakingConfig.PVP_EXTRA_WAIT), now + MatchmakingConfig.PVP_EXTRA_WAIT)
	else
		gatherDeadline = gatherDeadline or (now + MatchmakingConfig.SOLO_MAX_WAIT)
	end
end

local function tryStartMatch()
	if #queue == 0 then
		return
	end

	if gatherDeadline and os.clock() < gatherDeadline then
		return
	end

	if canStartMatch and not canStartMatch() then
		return
	end

	local ready = {}
	for _, player in queue do
		if player.Parent and (not getPlayerPhase or getPlayerPhase(player) == "arena") then
			table.insert(ready, player)
		end
	end

	if #ready == 0 then
		drainQueue()
		return
	end

	drainQueue()
	broadcastState()

	if onMatchReady then
		onMatchReady(ready)
	end
end

local function ensureTickLoop()
	if tickTask then
		return
	end

	tickTask = task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.TICK_INTERVAL)
			if #queue > 0 then
				-- Drop disconnected or players who left the arena
				for i = #queue, 1, -1 do
					local player = queue[i]
					if not player.Parent or (getPlayerPhase and getPlayerPhase(player) ~= "arena") then
						removeFromQueue(player)
						if player.Parent then
							remotes.QueueState:FireClient(player, { inQueue = false })
						end
					end
				end

				if #queue > 0 then
					broadcastState()
					tryStartMatch()
				end
			end
		end
	end)
end

function MatchmakingService.init(options)
	remotes = options.remotes
	onMatchReady = options.onMatchReady
	canStartMatch = options.canStartMatch
	getPlayerPhase = options.getPlayerPhase

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		if removeFromQueue(player) then
			remotes.QueueState:FireClient(player, { inQueue = false })
			broadcastState()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		if removeFromQueue(player) then
			broadcastState()
		end
	end)

	ensureTickLoop()
	initialized = true

	for _, player in pendingJoins do
		MatchmakingService.joinQueue(player)
	end
	table.clear(pendingJoins)
end

function MatchmakingService.joinQueue(player)
	if not initialized then
		table.insert(pendingJoins, player)
		return
	end
	if isQueued(player) then
		remotes.QueueState:FireClient(player, buildStateFor(player))
		return
	end

	if getPlayerPhase and getPlayerPhase(player) ~= "arena" then
		return
	end

	table.insert(queue, player)
	queueIndex[player] = #queue
	refreshGatherDeadline()
	broadcastState()
	tryStartMatch()
end

function MatchmakingService.leaveQueue(player)
	if removeFromQueue(player) then
		remotes.QueueState:FireClient(player, { inQueue = false })
		broadcastState()
		return true
	end
	return false
end

function MatchmakingService.isQueued(player)
	return isQueued(player)
end

return MatchmakingService
