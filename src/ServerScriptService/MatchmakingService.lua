--[[
	MatchmakingService — per-mode queues for Training / 1v1 / FFA matches.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local HubService
task.defer(function()
	HubService = require(script.Parent.HubService)
end)

local MODE_REQUIREMENTS = {
	training = 1,
	pvp = 2,
	ffa = 3,
}

local FFA_MAX_PLAYERS = 8

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}

local function getModeLabel(modeId)
	for _, pad in pairs(HubConfig.MODE_PADS) do
		if pad.id == modeId then
			return pad.label
		end
	end
	return modeId
end

local function buildQueueSnapshot()
	local snapshot = {}
	for modeId, required in pairs(MODE_REQUIREMENTS) do
		snapshot[modeId] = {
			count = #queues[modeId],
			required = required,
			label = getModeLabel(modeId),
		}
	end
	return snapshot
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end

	playerQueue[player] = nil
	local list = queues[modeId]
	for i, p in ipairs(list) do
		if p == player then
			table.remove(list, i)
			break
		end
	end
	return modeId
end

local function sendQueueUpdate(player)
	local modeId = playerQueue[player]
	local modeLabel = modeId and getModeLabel(modeId) or nil
	local payload = {
		queued = modeId ~= nil,
		modeId = modeId,
		queueModeLabel = modeLabel,
		count = modeId and #queues[modeId] or 0,
		required = modeId and MODE_REQUIREMENTS[modeId] or 0,
		queues = buildQueueSnapshot(),
	}

	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueueUpdates()
	for _, player in Players:GetPlayers() do
		sendQueueUpdate(player)
	end
	if HubService then
		HubService.notifyQueueChanged()
	end
end

local function tryStartMatch(modeId)
	local list = queues[modeId]
	local required = MODE_REQUIREMENTS[modeId]
	if not list or #list < required then
		return
	end

	local matchSize = required
	if modeId == "ffa" then
		matchSize = math.min(#list, FFA_MAX_PLAYERS)
	end

	local matchPlayers = {}
	for _ = 1, matchSize do
		local player = table.remove(list, 1)
		if player and player.Parent then
			table.insert(matchPlayers, player)
			playerQueue[player] = nil
		end
	end

	if #matchPlayers < required then
		for _, player in matchPlayers do
			table.insert(queues[modeId], player)
			playerQueue[player] = modeId
		end
		return
	end

	broadcastQueueUpdates()
	Bindables.StartMatch:Fire(matchPlayers, modeId)
end

local MatchmakingService = {}

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MODE_REQUIREMENTS[modeId] then
		return false
	end
	if not player.Parent then
		return false
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	broadcastQueueUpdates()
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end
	removeFromQueue(player)
	broadcastQueueUpdates()
	return true
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.getQueueSnapshot()
	return buildQueueSnapshot()
end

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Players.PlayerRemoving:Connect(function(player)
	removeFromQueue(player)
end)

return MatchmakingService
