local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(ReplicatedStorage.NovaBladers.MatchStateService)

local MatchmakingService = {}

local remotes
local bindables
local hubCallbacks

local queues = {}
local playerQueue = {}
local fillTimers = {}

local function getMode(modeId)
	return MatchModes[modeId]
end

local function initQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = { players = {} }
	end
	return queues[modeId]
end

local function cancelFillTimer(modeId)
	local timer = fillTimers[modeId]
	if timer then
		task.cancel(timer)
		fillTimers[modeId] = nil
	end
end

local function getQueueStatus(modeId)
	local mode = getMode(modeId)
	local queue = initQueue(modeId)
	local count = #queue.players
	local status = "waiting"

	if MatchStateService.isBusy() then
		status = "pending"
	elseif modeId == "ffa" and count >= mode.minPlayers and fillTimers[modeId] then
		status = "filling"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
	}
end

local function buildPlayerUpdate(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local update = getQueueStatus(modeId)
	update.inQueue = true
	return update
end

local function broadcastQueue(modeId)
	local queue = initQueue(modeId)
	for _, player in queue.players do
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, buildPlayerUpdate(player))
		end
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = initQueue(modeId)
	for i, queued in queue.players do
		if queued == player then
			table.remove(queue.players, i)
			break
		end
	end

	playerQueue[player] = nil

	local mode = getMode(modeId)
	if modeId == "ffa" and #queue.players < mode.minPlayers then
		cancelFillTimer(modeId)
	end

	broadcastQueue(modeId)
end

local function pullPlayers(modeId, count)
	local queue = initQueue(modeId)
	local pulled = {}
	for _ = 1, math.min(count, #queue.players) do
		local player = table.remove(queue.players, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(pulled, player)
		end
	end
	cancelFillTimer(modeId)
	return pulled
end

local function startMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	MatchStateService.setBusy(modeId)

	for _, player in playerList do
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, { inQueue = false, status = "starting" })
		end
	end

	if hubCallbacks.onMatchStarting then
		hubCallbacks.onMatchStarting(playerList)
	end

	bindables.MatchReady:Fire(playerList, modeId)
end

local function tryStartMode(modeId)
	if MatchStateService.isBusy() then
		return
	end

	local mode = getMode(modeId)
	if not mode then
		return
	end

	local queue = initQueue(modeId)
	local count = #queue.players

	if modeId == "training" and count >= 1 then
		startMatch(modeId, pullPlayers(modeId, 1))
	elseif modeId == "pvp" and count >= 2 then
		startMatch(modeId, pullPlayers(modeId, 2))
	elseif modeId == "ffa" then
		if count >= mode.maxPlayers then
			startMatch(modeId, pullPlayers(modeId, mode.maxPlayers))
		elseif count >= mode.minPlayers and not fillTimers[modeId] then
			local deadline = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
			fillTimers[modeId] = task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
				fillTimers[modeId] = nil
				if MatchStateService.isBusy() then
					return
				end
				local current = initQueue(modeId)
				if #current.players >= mode.minPlayers then
					startMatch(modeId, pullPlayers(modeId, #current.players))
				end
			end)

			task.spawn(function()
				while fillTimers[modeId] and not MatchStateService.isBusy() do
					local remaining = math.max(0, math.ceil(deadline - os.clock()))
					for _, player in queue.players do
						if player.Parent then
							local update = buildPlayerUpdate(player)
							update.fillSecondsLeft = remaining
							remotes.QueueUpdate:FireClient(player, update)
						end
					end
					if remaining <= 0 then
						break
					end
					task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
				end
			end)
		end
	end
end

local function tryStartAllModes()
	for modeId in MatchModes do
		tryStartMode(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not getMode(modeId) then
		return false, "invalid_mode"
	end

	if MatchStateService.isBusy() and playerQueue[player] == modeId then
		remotes.QueueUpdate:FireClient(player, buildPlayerUpdate(player))
		return true
	end

	removeFromQueue(player)

	local queue = initQueue(modeId)
	if #queue.players >= getMode(modeId).maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue.players, player)
	playerQueue[player] = modeId

	remotes.QueueUpdate:FireClient(player, buildPlayerUpdate(player))
	broadcastQueue(modeId)
	tryStartMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	removeFromQueue(player)
	remotes.QueueUpdate:FireClient(player, { inQueue = false })
end

function MatchmakingService.getActiveModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setIdle()
	task.defer(tryStartAllModes)
end

function MatchmakingService.init(remoteFolder, bindableFolder, callbacks)
	remotes = remoteFolder
	bindables = bindableFolder
	hubCallbacks = callbacks or {}

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getActiveModeId()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
