local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingService = require(script.Parent.MatchmakingService)
local MatchGate = require(script.Parent.MatchGate)
local MatchCoordinator = require(script.Parent.MatchCoordinator)
local HubService = require(script.Parent.HubService)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()
local QueueJoin = Remotes.QueueJoin
local QueueLeave = Remotes.QueueLeave
local QueueUpdate = Remotes.QueueUpdate
local MatchReady = Bindables.MatchReady

local matchGate

local service = MatchmakingService.new({
	onQueueUpdate = function(player, payload)
		if player.Parent then
			QueueUpdate:FireClient(player, payload)
		end
	end,
	onMatchReady = function(players, modeId)
		local started = matchGate:requestMatch(players, modeId)
		if not started then
			local mode = MatchmakingConfig.getMode(modeId)
			for _, player in players do
				if player.Parent then
					HubService.enterQueue(player, modeId)
					QueueUpdate:FireClient(player, {
						inQueue = true,
						modeId = modeId,
						modeLabel = mode and mode.label or modeId,
						current = #players,
						needed = #players,
						waitingForArena = true,
					})
				end
			end
		end
	end,
})

local function startMatchedPlayers(players, modeId)
	for _, player in players do
		if player.Parent then
			HubService.enterArena(player)
		end
	end

	local activePlayers = {}
	for _, player in players do
		if player.Parent then
			table.insert(activePlayers, player)
		end
	end

	if #activePlayers == 0 then
		matchGate:onMatchEnded()
		return
	end

	MatchReady:Fire(activePlayers, modeId)
end

matchGate = MatchGate.new({
	isBusy = MatchCoordinator.isBusy,
	startMatch = startMatchedPlayers,
})

local function joinQueue(player, modeId)
	if MatchCoordinator.isBusy() then
		return
	end
	if HubService.getPhase(player) == "arena" then
		return
	end

	if service:joinQueue(player, modeId) then
		HubService.enterQueue(player, modeId)
	end
end

local function leaveQueue(player)
	service:leaveQueue(player)
	HubService.leaveQueue(player)
end

QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingConfig.resolveAutoMode(#Players:GetPlayers())
	end
	joinQueue(player, modeId)
end)

QueueLeave.OnServerEvent:Connect(function(player)
	leaveQueue(player)
end)

Players.PlayerRemoving:Connect(function(player)
	service:clearPlayer(player)
end)

MatchCoordinator.register({
	onMatchEnded = function()
		matchGate:onMatchEnded()
	end,
})

HubService.register({
	requestJoinQueue = function(player, modeId)
		joinQueue(player, modeId)
	end,
})

print("[MatchmakingManager] Queue ready — Training / PvP / FFA")
