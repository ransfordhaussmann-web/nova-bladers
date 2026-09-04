--[[
	MatchmakingService — mode-based player queues for Training / 1v1 / FFA.
]]

local Players = game:GetService("Players")

local MatchmakingService = {}

local QUEUE_CONFIG = {
	training = { min = 1, max = 1, label = "Training" },
	pvp = { min = 2, max = 2, label = "1v1 PvP" },
	ffa = { min = 3, max = 8, label = "FFA" },
}

local GATHER_DELAY = 2
local FFA_FALLBACK_TIMEOUT = 30

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local playerMode = {}
local ffaWaitStart = {}
local onMatchReady = nil
local gatherToken = 0

local function getQueueSize(mode)
	return #queues[mode]
end

local function buildStatus(player)
	local mode = playerMode[player]
	if not mode then
		return {
			inQueue = false,
			mode = nil,
			waiting = 0,
			needed = 0,
			label = nil,
		}
	end

	local cfg = QUEUE_CONFIG[mode]
	return {
		inQueue = true,
		mode = mode,
		waiting = getQueueSize(mode),
		needed = cfg.min,
		label = cfg.label,
	}
end

local function broadcastQueueUpdate()
	for mode, list in queues do
		for _, player in list do
			if player.Parent then
				MatchmakingService._fireUpdate(player, buildStatus(player))
			end
		end
	end
end

function MatchmakingService._fireUpdate(player, status)
	if MatchmakingService._updateRemote then
		MatchmakingService._updateRemote:FireClient(player, status)
	end
end

function MatchmakingService.setUpdateRemote(remote)
	MatchmakingService._updateRemote = remote
end

function MatchmakingService.onMatchReady(callback)
	onMatchReady = callback
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.setPreferredMode(player, mode)
	if QUEUE_CONFIG[mode] then
		playerMode[player] = mode
	end
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.leave(player)
	local mode = playerQueue[player]
	if not mode then
		MatchmakingService._fireUpdate(player, buildStatus(player))
		return
	end

	local list = queues[mode]
	for i, queued in list do
		if queued == player then
			table.remove(list, i)
			break
		end
	end

	playerQueue[player] = nil
	ffaWaitStart[mode] = nil

	MatchmakingService._fireUpdate(player, buildStatus(player))
	broadcastQueueUpdate()
end

local function pullPlayers(mode, count)
	local pulled = {}
	local list = queues[mode]
	while #pulled < count and #list > 0 do
		local player = table.remove(list, 1)
		playerQueue[player] = nil
		table.insert(pulled, player)
	end
	return pulled
end

local function startGather(players, mode)
	if #players == 0 or not onMatchReady then
		return
	end

	gatherToken += 1
	local token = gatherToken

	task.delay(GATHER_DELAY, function()
		if token ~= gatherToken then
			return
		end

		local ready = {}
		for _, player in players do
			if player.Parent then
				table.insert(ready, player)
			end
		end

		if #ready == 0 then
			return
		end

		onMatchReady(ready, mode)
		broadcastQueueUpdate()
	end)
end

local function tryStartMatch(mode)
	local cfg = QUEUE_CONFIG[mode]
	local size = getQueueSize(mode)

	if size >= cfg.min then
		local players = pullPlayers(mode, math.min(size, cfg.max))
		ffaWaitStart[mode] = nil
		startGather(players, mode)
		return true
	end

	return false
end

function MatchmakingService.join(player, mode)
	if not QUEUE_CONFIG[mode] then
		return
	end

	MatchmakingService.leave(player)
	playerMode[player] = mode

	table.insert(queues[mode], player)
	playerQueue[player] = mode

	if mode == "ffa" and getQueueSize(mode) == 2 and not ffaWaitStart[mode] then
		ffaWaitStart[mode] = os.clock()
	end

	MatchmakingService._fireUpdate(player, buildStatus(player))
	broadcastQueueUpdate()
	tryStartMatch(mode)
end

function MatchmakingService.tick()
	local now = os.clock()

	if getQueueSize("ffa") == 2 and ffaWaitStart.ffa then
		if now - ffaWaitStart.ffa >= FFA_FALLBACK_TIMEOUT then
			local players = pullPlayers("ffa", 2)
			ffaWaitStart.ffa = nil
			if #players == 2 then
				startGather(players, "pvp")
			end
		end
	end
end

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.leave(player)
	playerMode[player] = nil
end)

return MatchmakingService
