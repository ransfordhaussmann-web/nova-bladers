--[[
	MatchmakingService — queue state, fill timers, and MatchReady dispatch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local arenaBusy = false
local pendingMatch = nil
local fillTokens = {}
local onQueueUpdate = nil
local onMatchReady = nil

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function queueCount(modeId)
	return #queues[modeId]
end

local function findPlayerIndex(modeId, player)
	for index, queuedPlayer in queues[modeId] do
		if queuedPlayer == player then
			return index
		end
	end
	return nil
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return nil
	end

	local index = findPlayerIndex(modeId, player)
	if index then
		table.remove(queues[modeId], index)
	end
	playerMode[player] = nil

	if modeId == "ffa" and queueCount("ffa") < getModeConfig("ffa").minPlayers then
		fillTokens.ffa += 1
	end

	return modeId
end

local function buildStatus(player)
	local modeId = playerMode[player]
	if not modeId then
		return { inQueue = false }
	end

	local config = getModeConfig(modeId)
	local count = queueCount(modeId)
	local status = "waiting"
	local message = string.format("Warte auf Spieler (%d/%d)", count, config.minPlayers)

	if arenaBusy then
		status = "pending"
		message = "Arena belegt — du bist als Nächstes dran"
	elseif count >= config.maxPlayers then
		status = "starting"
		message = "Match startet gleich..."
	elseif modeId == "ffa" and count >= config.minPlayers then
		message = string.format("FFA füllt sich (%d/%d)", count, config.maxPlayers)
	end

	return {
		inQueue = true,
		mode = modeId,
		modeLabel = config.label,
		count = count,
		needed = config.minPlayers,
		maxPlayers = config.maxPlayers,
		status = status,
		message = message,
	}
end

local function notifyPlayer(player)
	if onQueueUpdate and player.Parent then
		onQueueUpdate(player, buildStatus(player))
	end
end

local function notifyQueue(modeId)
	for _, player in queues[modeId] do
		notifyPlayer(player)
	end
end

local function notifyAllQueued()
	for queuedPlayer, _ in playerMode do
		if queuedPlayer.Parent then
			notifyPlayer(queuedPlayer)
		end
	end
end

local function takePlayers(modeId, amount)
	local taken = {}
	for _ = 1, amount do
		local player = table.remove(queues[modeId], 1)
		if not player then
			break
		end
		playerMode[player] = nil
		table.insert(taken, player)
	end
	return taken
end

local function dispatchMatch(modeId, playerList)
	pendingMatch = nil
	for _, player in playerList do
		removeFromQueue(player)
	end

	arenaBusy = true
	notifyAllQueued()

	if onMatchReady then
		onMatchReady({
			mode = modeId,
			players = playerList,
		})
	end
end

local function tryStartMode(modeId)
	local config = getModeConfig(modeId)
	if not config then
		return
	end

	local count = queueCount(modeId)
	if count < config.minPlayers then
		return
	end

	if count >= config.maxPlayers then
		local players = takePlayers(modeId, config.maxPlayers)
		if #players >= config.minPlayers then
			dispatchMatch(modeId, players)
		end
		return
	end

	if config.fillTimeout and count >= config.minPlayers then
		return
	end

	if not config.fillTimeout then
		local players = takePlayers(modeId, config.minPlayers)
		if #players >= config.minPlayers then
			dispatchMatch(modeId, players)
		end
	end
end

local function tryStartAnyMatch()
	if arenaBusy then
		return
	end

	for _, modeId in MatchmakingConfig.MODE_ORDER do
		tryStartMode(modeId)
		if arenaBusy then
			break
		end
	end
end

local function scheduleFillTimer(modeId)
	local config = getModeConfig(modeId)
	if not config or not config.fillTimeout then
		return
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.delay(config.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end
		if arenaBusy then
			local count = queueCount(modeId)
			if count >= config.minPlayers then
				local players = takePlayers(modeId, math.min(count, config.maxPlayers))
				pendingMatch = {
					mode = modeId,
					players = players,
				}
				notifyAllQueued()
			end
			return
		end

		local count = queueCount(modeId)
		if count >= config.minPlayers then
			local players = takePlayers(modeId, math.min(count, config.maxPlayers))
			dispatchMatch(modeId, players)
		end
	end)
end

function MatchmakingService.registerHandlers(handlers)
	onQueueUpdate = handlers.onQueueUpdate
	onMatchReady = handlers.onMatchReady
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	notifyAllQueued()

	if not busy then
		if pendingMatch then
			local match = pendingMatch
			pendingMatch = nil
			dispatchMatch(match.mode, match.players)
		else
			tryStartAnyMatch()
		end
	end
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not getModeConfig(modeId) then
		return false, "Ungültiger Modus"
	end

	if playerMode[player] == modeId then
		notifyPlayer(player)
		return true
	end

	local previousMode = removeFromQueue(player)
	if previousMode then
		notifyQueue(previousMode)
	end

	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	notifyQueue(modeId)

	if modeId == "ffa" and queueCount("ffa") == getModeConfig("ffa").minPlayers then
		scheduleFillTimer("ffa")
	end

	if arenaBusy then
		notifyPlayer(player)
		return true
	end

	tryStartMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerMode[player] then
		notifyPlayer(player)
		return
	end

	local modeId = removeFromQueue(player)
	if modeId then
		notifyQueue(modeId)
	end
	notifyPlayer(player)
end

function MatchmakingService.clearPlayer(player)
	removeFromQueue(player)
end

function MatchmakingService.getRecommendedMode()
	return MatchmakingConfig.getRecommendedMode(#Players:GetPlayers())
end

function MatchmakingService.buildStatus(player)
	return buildStatus(player)
end

Players.PlayerRemoving:Connect(function(player)
	removeFromQueue(player)
end)

return MatchmakingService
