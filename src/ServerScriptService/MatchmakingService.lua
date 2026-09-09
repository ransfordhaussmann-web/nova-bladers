local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local fillTimers = {}
local fillTokens = {}

local function getQueue(modeId)
	return queues[modeId]
end

local function isInQueue(player)
	return playerMode[player] ~= nil
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i, p in queue do
		if p == player then
			table.remove(queue, i)
			break
		end
	end
	playerMode[player] = nil
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	fillTimers[modeId] = nil
end

local function getModeConfig(modeId)
	return MatchmakingConfig.getMode(modeId)
end

local function buildQueuePayload(player, modeId)
	local config = getModeConfig(modeId)
	local queue = getQueue(modeId)
	local names = {}
	for _, p in queue do
		if p.Parent then
			table.insert(names, p.DisplayName)
		end
	end

	local status = "waiting"
	if MatchStateService.isArenaBusy() then
		status = "pending"
	end

	return {
		modeId = modeId,
		modeLabel = config.label,
		players = names,
		count = #names,
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		fillTimeout = config.fillTimeout,
		status = status,
		inQueue = true,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
		end
	end
end

local function clearQueueUI(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

local function popPlayers(modeId, count)
	local queue = getQueue(modeId)
	local popped = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerMode[player] = nil
			table.insert(popped, player)
		end
	end
	return popped
end

local function launchMatch(modeId, playerList)
	cancelFillTimer(modeId)
	MatchStateService.setArenaBusy(true)
	Bindables.MatchReady:Fire({
		mode = modeId,
		players = playerList,
	})

	for _, player in playerList do
		clearQueueUI(player)
	end
end

local function tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		return
	end

	local config = getModeConfig(modeId)
	local queue = getQueue(modeId)

	if #queue >= config.maxPlayers then
		launchMatch(modeId, popPlayers(modeId, config.maxPlayers))
		return
	end

	if #queue >= config.minPlayers then
		if config.fillTimeout and config.fillTimeout > 0 then
			if not fillTimers[modeId] then
				local token = (fillTokens[modeId] or 0) + 1
				fillTokens[modeId] = token
				fillTimers[modeId] = true

				task.delay(config.fillTimeout, function()
					if fillTokens[modeId] ~= token then
						return
					end
					fillTimers[modeId] = nil

					if MatchStateService.isArenaBusy() then
						return
					end

					local current = getQueue(modeId)
					if #current >= config.minPlayers then
						launchMatch(modeId, popPlayers(modeId, #current))
					end
				end)
			end
		else
			launchMatch(modeId, popPlayers(modeId, #queue))
		end
	end
end

local function onArenaFreed()
	for modeId in queues do
		tryStartMatch(modeId)
		broadcastQueueUpdate(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not getModeConfig(modeId) then
		return false, "invalid_mode"
	end
	if isInQueue(player) then
		if playerMode[player] == modeId then
			return true
		end
		MatchmakingService.leaveQueue(player)
	end

	local queue = getQueue(modeId)
	if #queue >= getModeConfig(modeId).maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue, player)
	playerMode[player] = modeId

	if MatchStateService.isArenaBusy() then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
		return true
	end

	broadcastQueueUpdate(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		clearQueueUI(player)
		return
	end

	removeFromQueue(player)
	cancelFillTimer(modeId)
	clearQueueUI(player)
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	task.defer(onArenaFreed)
end

function MatchmakingService.getSuggestedMode()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.init()
	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
