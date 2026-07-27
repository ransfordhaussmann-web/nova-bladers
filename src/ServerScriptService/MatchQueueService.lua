--[[
	MatchQueueService — queues players by mode and starts matches when enough players are ready.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes = RemotesSetup.ensure()

local MIN_PLAYERS = {
	training = 1,
	pvp = 2,
	ffa = 3,
}

local MAX_FFA_PLAYERS = 6

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local onMatchReady = nil

local MatchQueueService = {}

local function buildSnapshot(forPlayer)
	local snapshot = {
		queues = {},
		inQueue = false,
		modeId = nil,
		position = 0,
		needed = 0,
	}

	for modeId, list in queues do
		snapshot.queues[modeId] = {
			count = #list,
			needed = MIN_PLAYERS[modeId],
		}
	end

	if forPlayer and playerQueue[forPlayer] then
		local modeId = playerQueue[forPlayer]
		local list = queues[modeId]
		snapshot.inQueue = true
		snapshot.modeId = modeId
		snapshot.needed = MIN_PLAYERS[modeId]
		for i, p in list do
			if p == forPlayer then
				snapshot.position = i
				break
			end
		end
	end

	return snapshot
end

local function broadcastUpdate()
	for _, player in Players:GetPlayers() do
		if player.Parent then
			Remotes.MatchQueueUpdate:FireClient(player, buildSnapshot(player))
		end
	end
end

local function removeFromList(list, player)
	for i, p in list do
		if p == player then
			table.remove(list, i)
			return true
		end
	end
	return false
end

local function pullPlayers(modeId)
	local list = queues[modeId]
	local needed = MIN_PLAYERS[modeId]
	if #list < needed then
		return nil
	end

	local count = needed
	if modeId == "ffa" then
		count = math.min(#list, MAX_FFA_PLAYERS)
	end

	local players = {}
	for _ = 1, count do
		local player = table.remove(list, 1)
		if player and player.Parent then
			table.insert(players, player)
			playerQueue[player] = nil
		end
	end

	if #players < needed then
		for _, player in players do
			table.insert(list, player)
			playerQueue[player] = modeId
		end
		return nil
	end

	return players
end

local function tryStartMatches()
	for modeId in MIN_PLAYERS do
		while true do
			local players = pullPlayers(modeId)
			if not players then
				break
			end
			if onMatchReady then
				onMatchReady(players, modeId)
			end
		end
	end
	broadcastUpdate()
end

function MatchQueueService.registerOnMatchReady(handler)
	onMatchReady = handler
end

function MatchQueueService.join(player, modeId)
	if not MIN_PLAYERS[modeId] then
		return false
	end
	if playerQueue[player] then
		MatchQueueService.leave(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	broadcastUpdate()
	tryStartMatches()
	return true
end

function MatchQueueService.leave(player)
	local modeId = playerQueue[player]
	if not modeId then
		return false
	end

	playerQueue[player] = nil
	removeFromList(queues[modeId], player)
	broadcastUpdate()
	return true
end

function MatchQueueService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchQueueService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchQueueService.onPlayerRemoving(player)
	if playerQueue[player] then
		MatchQueueService.leave(player)
	end
end

function MatchQueueService.getSnapshot(player)
	return buildSnapshot(player)
end

Players.PlayerRemoving:Connect(function(player)
	MatchQueueService.onPlayerRemoving(player)
end)

return MatchQueueService
