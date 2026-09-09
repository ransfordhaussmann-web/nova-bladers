local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}
local playerQueue = {}
local fillTimers = {}

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function countValidPlayers(modeId)
	local count = 0
	for _, player in queues[modeId] do
		if player.Parent then
			count += 1
		end
	end
	return count
end

local function buildQueuePayload(modeId, status)
	local cfg = getModeConfig(modeId)
	local fillTimeLeft = nil
	local timer = fillTimers[modeId]
	if timer and status == "waiting" then
		fillTimeLeft = math.max(0, math.ceil(MatchmakingConfig.FILL_TIMEOUT - (os.clock() - timer.startTime)))
	end
	return {
		mode = modeId,
		modeLabel = cfg.label,
		players = countValidPlayers(modeId),
		minPlayers = cfg.minPlayers,
		maxPlayers = cfg.maxPlayers,
		fillTimeLeft = fillTimeLeft,
		status = status,
	}
end

local function broadcastQueueUpdate(modeId, status)
	local payload = buildQueuePayload(modeId, status)
	for _, player in queues[modeId] do
		if player.Parent and playerQueue[player] == modeId then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	for i = #queues[modeId], 1, -1 do
		if queues[modeId][i] == player then
			table.remove(queues[modeId], i)
		end
	end

	if countValidPlayers(modeId) == 0 then
		fillTimers[modeId] = nil
	end

	broadcastQueueUpdate(modeId, "waiting")
end

local function shouldStartMatch(modeId)
	local cfg = getModeConfig(modeId)
	local count = countValidPlayers(modeId)
	if count < cfg.minPlayers then
		return false
	end
	if count >= cfg.maxPlayers then
		return true
	end
	if modeId == "training" then
		return count >= 1
	end
	if modeId == "pvp" then
		return count >= 2
	end
	if modeId == "ffa" then
		local timer = fillTimers[modeId]
		if timer and os.clock() - timer.startTime >= MatchmakingConfig.FILL_TIMEOUT then
			return true
		end
	end
	return false
end

local function extractPlayersForMatch(modeId)
	local cfg = getModeConfig(modeId)
	local players = {}
	for _, player in queues[modeId] do
		if player.Parent then
			table.insert(players, player)
			if #players >= cfg.maxPlayers then
				break
			end
		end
	end
	return players
end

local function clearPlayersFromQueue(modeId, players)
	local playerSet = {}
	for _, p in players do
		playerSet[p] = true
		playerQueue[p] = nil
	end

	for i = #queues[modeId], 1, -1 do
		if playerSet[queues[modeId][i]] then
			table.remove(queues[modeId], i)
		end
	end

	if countValidPlayers(modeId) == 0 then
		fillTimers[modeId] = nil
	end
end

local function startMatch(modeId, players)
	clearPlayersFromQueue(modeId, players)
	MatchStateService.setBusy(true)

	for _, player in players do
		HubService.leaveHubForArena(player)
		Remotes.QueueUpdate:FireClient(player, { status = "starting", mode = modeId })
	end

	Bindables.MatchReady:Fire({
		players = players,
		mode = modeId,
	})
end

local function tryStartMatch(modeId)
	if not shouldStartMatch(modeId) then
		return
	end

	if MatchStateService.isBusy() then
		broadcastQueueUpdate(modeId, "pending")
		return
	end

	startMatch(modeId, extractPlayersForMatch(modeId))
end

local function ensureFillTimer(modeId)
	if modeId ~= "ffa" then
		return
	end

	local cfg = getModeConfig(modeId)
	if countValidPlayers(modeId) < cfg.minPlayers then
		return
	end
	if fillTimers[modeId] then
		return
	end

	local token = {}
	fillTimers[modeId] = {
		token = token,
		startTime = os.clock(),
	}

	task.delay(MatchmakingConfig.FILL_TIMEOUT, function()
		if not fillTimers[modeId] or fillTimers[modeId].token ~= token then
			return
		end
		tryStartMatch(modeId)
	end)

	task.spawn(function()
		while fillTimers[modeId] and fillTimers[modeId].token == token do
			local status = MatchStateService.isBusy() and shouldStartMatch(modeId) and "pending" or "waiting"
			broadcastQueueUpdate(modeId, status)
			if os.clock() - fillTimers[modeId].startTime >= MatchmakingConfig.FILL_TIMEOUT then
				break
			end
			task.wait(1)
		end
	end)
end

local MatchmakingService = {}

function MatchmakingService.joinQueue(player, modeId)
	if not getModeConfig(modeId) then
		return
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	local status = "waiting"
	if MatchStateService.isBusy() and shouldStartMatch(modeId) then
		status = "pending"
	end

	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, status))
	broadcastQueueUpdate(modeId, status)

	ensureFillTimer(modeId)
	tryStartMatch(modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { status = "idle" })
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setBusy(false)
	for modeId in queues do
		tryStartMatch(modeId)
		if not shouldStartMatch(modeId) then
			broadcastQueueUpdate(modeId, "waiting")
		end
	end
end

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.onMatchEnded()
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

print("[MatchmakingService] Queue ready")

return MatchmakingService
