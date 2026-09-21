local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local Bindables

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}
local leaveArena

local function copyQueue(modeId)
	local list = {}
	for _, player in queues[modeId] do
		if player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end

	playerQueue[player] = nil

	if fillTimers[modeId] and #queue < MatchModes.get(modeId).minPlayers then
		fillTimers[modeId] = nil
	end
end

local function getStatus(modeId)
	if MatchStateService.isBusy() then
		return "pending"
	end
	if fillTimers[modeId] then
		return "filling"
	end
	return "waiting"
end

local function buildUpdate(player, modeId)
	local mode = MatchModes.get(modeId)
	local queue = copyQueue(modeId)
	local status = getStatus(modeId)
	local payload = {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		count = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
	}

	if status == "filling" and fillTimers[modeId] then
		local elapsed = os.clock() - fillTimers[modeId].startedAt
		payload.fillSecondsLeft = math.max(0, math.ceil(mode.fillTimeout - elapsed))
	end

	return payload
end

local function broadcastQueue(modeId)
	local queue = copyQueue(modeId)
	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildUpdate(player, modeId))
		end
	end
end

local function sendClear(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
end

local function pruneQueue(modeId)
	local queue = queues[modeId]
	for i = #queue, 1, -1 do
		local player = queue[i]
		if not player.Parent or HubService.getPhase(player) ~= "hub" then
			table.remove(queue, i)
			playerQueue[player] = nil
		end
	end
end

local function resolveDefaultMode()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function launchMatch(modeId, playerList)
	MatchStateService.setBusy(true, modeId)
	fillTimers[modeId] = nil

	for _, player in playerList do
		removeFromQueue(player)
		if leaveArena then
			leaveArena(player)
		end
		Remotes.QueueUpdate:FireClient(player, {
			inQueue = true,
			modeId = modeId,
			modeLabel = MatchModes.get(modeId).label,
			count = #playerList,
			minPlayers = MatchModes.get(modeId).minPlayers,
			maxPlayers = MatchModes.get(modeId).maxPlayers,
			status = "starting",
		})
	end

	task.delay(MatchmakingConfig.STARTING_DELAY, function()
		Bindables.MatchReady:Fire({
			mode = modeId,
			players = playerList,
		})
	end)
end

local function tryStartMode(modeId)
	pruneQueue(modeId)

	local mode = MatchModes.get(modeId)
	local queue = copyQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	if MatchStateService.isBusy() then
		broadcastQueue(modeId)
		return
	end

	if #queue >= mode.maxPlayers then
		local players = {}
		for i = 1, mode.maxPlayers do
			table.insert(players, queue[i])
		end
		launchMatch(modeId, players)
		return
	end

	if mode.fillTimeout > 0 then
		if not fillTimers[modeId] then
			fillTimers[modeId] = {
				token = (fillTimers[modeId] and fillTimers[modeId].token or 0) + 1,
				startedAt = os.clock(),
			}
			local token = fillTimers[modeId].token
			broadcastQueue(modeId)

			task.delay(mode.fillTimeout, function()
				if not fillTimers[modeId] or fillTimers[modeId].token ~= token then
					return
				end
				fillTimers[modeId] = nil
				pruneQueue(modeId)
				local ready = copyQueue(modeId)
				if #ready >= mode.minPlayers and not MatchStateService.isBusy() then
					launchMatch(modeId, ready)
				else
					broadcastQueue(modeId)
				end
			end)
		else
			broadcastQueue(modeId)
		end
		return
	end

	launchMatch(modeId, queue)
end

local function tryStartAll()
	for _, mode in MatchModes.all() do
		tryStartMode(mode.id)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if modeId == nil then
		modeId = resolveDefaultMode()
	end
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		return false
	end
	if HubService.getPhase(player) ~= "hub" then
		return false
	end
	if playerQueue[player] == modeId then
		Remotes.QueueUpdate:FireClient(player, buildUpdate(player, modeId))
		return true
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	broadcastQueue(modeId)
	tryStartMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		sendClear(player)
		return
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	sendClear(player)
	broadcastQueue(modeId)
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setBusy(false)
	task.defer(tryStartAll)
end

function MatchmakingService.init(options)
	Remotes, Bindables = RemotesSetup.ensure()
	leaveArena = options.leaveHubForArena

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local modeId = playerQueue[player]
		removeFromQueue(player)
		if modeId then
			broadcastQueue(modeId)
			tryStartMode(modeId)
		end
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
