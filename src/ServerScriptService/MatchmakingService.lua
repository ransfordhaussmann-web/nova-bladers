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
local fillTokens = {}
local handlers = {}

local function getQueue(modeId)
	return queues[modeId]
end

local function countValidPlayers(modeId)
	local queue = getQueue(modeId)
	local count = 0
	for index = #queue, 1, -1 do
		local player = queue[index]
		if player.Parent then
			count += 1
		else
			table.remove(queue, index)
			playerQueue[player] = nil
		end
	end
	return count
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local playerNames = {}
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			table.insert(playerNames, queuedPlayer.DisplayName)
		end
	end

	local pending = MatchStateService.isBusy()
	local count = #playerNames
	local status = "waiting"
	if pending then
		status = "pending"
	elseif modeId == "training" and count >= 1 then
		status = "ready"
	elseif modeId == "pvp" and count >= 2 then
		status = "ready"
	elseif modeId == "ffa" and count >= mode.maxPlayers then
		status = "ready"
	elseif modeId == "ffa" and count >= mode.minPlayers and fillTokens[modeId] then
		status = "filling"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = playerNames,
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		pending = pending,
		fillTimeout = mode.fillTimeout,
		inQueue = playerQueue[player] == modeId,
	}
end

local function broadcastQueue(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for index = #queue, 1, -1 do
		if queue[index] == player then
			table.remove(queue, index)
			break
		end
	end
	playerQueue[player] = nil

	if modeId == "ffa" then
		fillTokens[modeId] = nil
	end

	broadcastQueue(modeId)
end

local function takePlayers(modeId, amount)
	local queue = getQueue(modeId)
	local picked = {}
	for index = #queue, 1, -1 do
		local player = queue[index]
		if player.Parent then
			table.insert(picked, 1, player)
			table.remove(queue, index)
			playerQueue[player] = nil
			if #picked >= amount then
				break
			end
		else
			table.remove(queue, index)
			playerQueue[player] = nil
		end
	end
	return picked
end

local function startMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	fillTokens[modeId] = nil
	MatchStateService.setBusy(true)

	for _, player in playerList do
		if handlers.leaveHubForArena then
			handlers.leaveHubForArena(player)
		end
		Remotes.QueueUpdate:FireClient(player, {
			modeId = modeId,
			status = "starting",
			inQueue = false,
		})
	end

	broadcastAllQueues()
	Bindables.MatchReady:Fire(playerList, modeId)
end

local function tryStartMode(modeId)
	if MatchStateService.isBusy() then
		return
	end

	local mode = MatchModes.get(modeId)
	local count = countValidPlayers(modeId)
	if count == 0 then
		return
	end

	if modeId == "training" and count >= 1 then
		startMatch(modeId, takePlayers(modeId, 1))
		return
	end

	if modeId == "pvp" and count >= 2 then
		startMatch(modeId, takePlayers(modeId, 2))
		return
	end

	if modeId == "ffa" then
		if count >= mode.maxPlayers then
			startMatch(modeId, takePlayers(modeId, mode.maxPlayers))
			return
		end

		if count >= mode.minPlayers and not fillTokens[modeId] then
			local token = {}
			fillTokens[modeId] = token
			broadcastQueue(modeId)

			task.delay(mode.fillTimeout or MatchmakingConfig.FFA_FILL_TIMEOUT, function()
				if fillTokens[modeId] ~= token or MatchStateService.isBusy() then
					return
				end
				fillTokens[modeId] = nil
				local readyCount = countValidPlayers(modeId)
				if readyCount >= mode.minPlayers then
					startMatch(modeId, takePlayers(modeId, math.min(readyCount, mode.maxPlayers)))
				else
					broadcastQueue(modeId)
				end
			end)
		end
	end
end

local function tryStartAll()
	for modeId in queues do
		tryStartMode(modeId)
	end
end

function MatchmakingService.init(newHandlers)
	handlers = newHandlers or {}
	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" or not MatchModes.isValid(modeId) then
			modeId = handlers.getActiveModeId and handlers.getActiveModeId() or "training"
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchStateService.setBusy(false)
		task.defer(tryStartAll)
	end)

	MatchStateService.onChanged(function(busy)
		if not busy then
			task.defer(tryStartAll)
		else
			broadcastAllQueues()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return
	end
	if handlers.getPhase and handlers.getPhase(player) ~= "hub" then
		return
	end

	removeFromQueue(player)

	local queue = getQueue(modeId)
	table.insert(queue, player)
	playerQueue[player] = modeId
	broadcastQueue(modeId)

	if not MatchStateService.isBusy() then
		tryStartMode(modeId)
	end
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false, status = "left" })
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

return MatchmakingService
