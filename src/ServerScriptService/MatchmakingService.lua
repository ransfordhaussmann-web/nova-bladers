local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local playerQueue = {}
local fillTokens = {}
local fillTimerActive = {}
local callbacks = {}

local Remotes
local MatchReady

local function getQueuePlayers(modeId)
	local list = {}
	for player, info in playerQueue do
		if info.modeId == modeId and player.Parent then
			table.insert(list, player)
		end
	end
	table.sort(list, function(a, b)
		return playerQueue[a].joinedAt < playerQueue[b].joinedAt
	end)
	return list
end

local function buildQueuePayload(player)
	local info = playerQueue[player]
	if not info then
		return { inQueue = false }
	end

	local mode = MatchModes.get(info.modeId)
	local queue = getQueuePlayers(info.modeId)
	return {
		inQueue = true,
		modeId = info.modeId,
		modeLabel = mode.label,
		count = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = info.status or "waiting",
		fillTimeout = mode.fillTimeout,
		arenaBusy = MatchStateService.isBusy(),
	}
end

local function notifyPlayer(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	end
end

local function broadcastMode(modeId)
	for _, player in getQueuePlayers(modeId) do
		notifyPlayer(player)
	end
end

local function setQueueStatus(modeId, status)
	for _, player in getQueuePlayers(modeId) do
		local info = playerQueue[player]
		if info then
			info.status = status
		end
	end
	broadcastMode(modeId)
end

local function removeFromQueue(player, silent)
	local info = playerQueue[player]
	if not info then
		return
	end

	local modeId = info.modeId
	playerQueue[player] = nil
	broadcastMode(modeId)

	if not silent and player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	fillTimerActive[modeId] = nil
end

local function takePlayers(modeId, count)
	local queue = getQueuePlayers(modeId)
	local picked = {}
	for i = 1, math.min(count, #queue) do
		table.insert(picked, queue[i])
	end
	return picked
end

local function launchMatch(modeId, matchPlayers)
	for _, player in matchPlayers do
		removeFromQueue(player, true)
	end

	cancelFillTimer(modeId)

	if callbacks.onMatchStarting then
		callbacks.onMatchStarting(modeId, matchPlayers)
	end

	for _, player in matchPlayers do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, { inQueue = false, starting = true })
		end
	end

	MatchReady:Fire(modeId, matchPlayers)
end

local function tryStartMode(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueuePlayers(modeId)
	if #queue == 0 then
		return
	end

	if MatchStateService.isBusy() then
		if #queue >= mode.minPlayers then
			setQueueStatus(modeId, "pending")
		end
		return
	end

	if modeId == "training" and #queue >= 1 then
		launchMatch(modeId, { queue[1] })
		return
	end

	if modeId == "pvp" and #queue >= 2 then
		launchMatch(modeId, takePlayers(modeId, 2))
		return
	end

	if modeId == "ffa" then
		if #queue >= mode.maxPlayers then
			cancelFillTimer(modeId)
			launchMatch(modeId, takePlayers(modeId, mode.maxPlayers))
		end
	end
end

local function scheduleFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout or fillTimerActive[modeId] then
		return
	end

	fillTimerActive[modeId] = true
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout, function()
		fillTimerActive[modeId] = nil
		if fillTokens[modeId] ~= token then
			return
		end

		local queue = getQueuePlayers(modeId)
		if #queue < mode.minPlayers then
			return
		end

		if MatchStateService.isBusy() then
			setQueueStatus(modeId, "pending")
			return
		end

		launchMatch(modeId, takePlayers(modeId, math.min(#queue, mode.maxPlayers)))
	end)
end

local function onQueueChanged(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueuePlayers(modeId)
	if modeId == "ffa" then
		if #queue >= mode.minPlayers then
			scheduleFillTimer(modeId)
		else
			cancelFillTimer(modeId)
		end
	end

	tryStartMode(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchModes.resolveAuto(#Players:GetPlayers())
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	removeFromQueue(player, true)

	playerQueue[player] = {
		modeId = modeId,
		joinedAt = os.clock(),
		status = "waiting",
	}

	notifyPlayer(player)
	broadcastMode(modeId)
	onQueueChanged(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player, false)
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.init(hubCallbacks)
	callbacks = hubCallbacks or {}
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	MatchStateService.onBusyChanged(function(isBusy)
		if isBusy then
			return
		end
		for _, mode in MatchModes.all() do
			tryStartMode(mode.id)
		end
	end)

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = nil
		end
		MatchmakingService.joinQueue(player, modeId or MatchModes.resolveAuto(#Players:GetPlayers()))
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player, true)
	end)
end

return MatchmakingService
