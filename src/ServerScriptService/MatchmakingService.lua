local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {
	training = {},
	pvp = {},
	ffa = {},
}
local playerQueue = {}
local ffaFillToken = 0
local onMatchReady
local onPlayerEnterArena

local function getQueueList(modeId)
	local list = {}
	for _, player in queues[modeId] do
		if player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

local function buildUpdatePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local queue = getQueueList(modeId)
	local pending = MatchStateService.isBusy()

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		players = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = pending,
	}
end

local function broadcastQueueUpdate(modeId)
	local payload = {}
	for _, player in getQueueList(modeId) do
		payload[player] = buildUpdatePayload(player)
	end

	for player, update in payload do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, update)
		end
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end
	broadcastQueueUpdate(modeId)
end

local function popPlayers(modeId, count)
	local taken = {}
	local queue = queues[modeId]
	local i = 1
	while #taken < count and i <= #queue do
		local player = queue[i]
		if player.Parent and playerQueue[player] == modeId then
			table.insert(taken, player)
			playerQueue[player] = nil
			table.remove(queue, i)
		else
			table.remove(queue, i)
		end
	end
	return taken
end

local function startMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	for _, player in playerList do
		if onPlayerEnterArena then
			onPlayerEnterArena(player)
		end
	end

	Bindables.MatchReady:Fire(playerList, modeId)
end

local function tryStartMode(modeId)
	if MatchStateService.isBusy() then
		broadcastQueueUpdate(modeId)
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueueList(modeId)
	if #queue < mode.minPlayers then
		return
	end

	if modeId == "ffa" then
		return
	end

	local players = popPlayers(modeId, mode.maxPlayers)
	startMatch(modeId, players)
	broadcastQueueUpdate(modeId)
end

local function scheduleFfaFill()
	ffaFillToken += 1
	local token = ffaFillToken
	local mode = MatchModes.ffa

	task.delay(mode.fillTimeout or MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if token ~= ffaFillToken then
			return
		end
		if MatchStateService.isBusy() then
			broadcastQueueUpdate("ffa")
			return
		end

		local queue = getQueueList("ffa")
		if #queue < mode.minPlayers then
			return
		end

		local players = popPlayers("ffa", mode.maxPlayers)
		ffaFillToken += 1
		startMatch("ffa", players)
		broadcastQueueUpdate("ffa")
	end)
end

local function tryStartFfa()
	if MatchStateService.isBusy() then
		broadcastQueueUpdate("ffa")
		return
	end

	local queue = getQueueList("ffa")
	local mode = MatchModes.ffa
	if #queue < mode.minPlayers then
		return
	end

	if #queue >= mode.maxPlayers then
		local players = popPlayers("ffa", mode.maxPlayers)
		ffaFillToken += 1
		startMatch("ffa", players)
		broadcastQueueUpdate("ffa")
		return
	end

	scheduleFfaFill()
end

local function joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return
	end
	if playerQueue[player] == modeId then
		Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(player))
		return
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(player))
	broadcastQueueUpdate(modeId)

	if modeId == "ffa" then
		tryStartFfa()
	else
		tryStartMode(modeId)
	end
end

local function leaveQueue(player)
	if not playerQueue[player] then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })

	if modeId == "ffa" then
		local queue = getQueueList("ffa")
		if #queue < MatchModes.ffa.minPlayers then
			ffaFillToken += 1
		end
	end
end

function MatchmakingService.getQuickMatchMode()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.joinMode(player, modeId)
	joinQueue(player, modeId)
end

function MatchmakingService.joinQuickMatch(player)
	joinQueue(player, MatchmakingService.getQuickMatchMode())
end

function MatchmakingService.onArenaFree()
	for modeId in queues do
		if modeId == "ffa" then
			tryStartFfa()
		else
			tryStartMode(modeId)
		end
	end
end

function MatchmakingService.init(handlers)
	Remotes, Bindables = RemotesSetup.ensure()
	onPlayerEnterArena = handlers and handlers.onPlayerEnterArena

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			MatchmakingService.joinQuickMatch(player)
			return
		end
		joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		leaveQueue(player)
	end)
end

return MatchmakingService
