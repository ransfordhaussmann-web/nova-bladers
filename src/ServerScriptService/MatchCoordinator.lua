local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingService = require(script.Parent.MatchmakingService)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchCoordinator = {}

local Bindables
local gatherTokens = {}
local initialized = false

local function ensureInit()
	if initialized then
		return
	end
	local _, bindables = RemotesSetup.ensure()
	Bindables = bindables
	initialized = true
end

local function tryStartMode(modeId)
	ensureInit()
	if not MatchStateService.isIdle() then
		local config = MatchmakingConfig.MODES[modeId]
		local queue = MatchmakingService.getQueue(modeId)
		if config and #queue >= config.minPlayers then
			MatchmakingService.markPendingArena(queue, modeId)
		end
		return false
	end

	local config = MatchmakingConfig.MODES[modeId]
	local queue = MatchmakingService.getQueue(modeId)
	if not config or #queue < config.minPlayers then
		return false
	end

	local players = MatchmakingService.popReadyPlayers(modeId)
	if not players or #players < config.minPlayers then
		return false
	end

	gatherTokens[modeId] = nil
	MatchmakingService.markGathering(modeId, false)
	MatchStateService.setIdle(false)

	for _, player in players do
		HubService.enterArena(player)
	end

	Bindables.MatchReady:Fire({
		players = players,
		mode = modeId,
	})

	return true
end

function MatchCoordinator.init(_remotes, bindables)
	if bindables then
		Bindables = bindables
		initialized = true
	end
end

function MatchCoordinator.scheduleGather(modeId)
	ensureInit()
	local config = MatchmakingConfig.MODES[modeId]
	if not config then
		return
	end

	local queue = MatchmakingService.getQueue(modeId)
	if #queue < config.minPlayers then
		return
	end

	if gatherTokens[modeId] then
		return
	end

	gatherTokens[modeId] = (gatherTokens[modeId] or 0) + 1
	local token = gatherTokens[modeId]
	MatchmakingService.markGathering(modeId, true)

	task.delay(config.gatherDelay, function()
		if token ~= gatherTokens[modeId] then
			return
		end
		gatherTokens[modeId] = nil
		MatchmakingService.markGathering(modeId, false)
		tryStartMode(modeId)
	end)
end

function MatchCoordinator.onQueueChanged(modeId)
	ensureInit()
	if gatherTokens[modeId] then
		return
	end
	MatchCoordinator.scheduleGather(modeId)
end

function MatchCoordinator.onMatchEnded()
	ensureInit()
	MatchStateService.setIdle(true)
	for modeId in MatchmakingConfig.MODES do
		if tryStartMode(modeId) then
			break
		end
		MatchCoordinator.scheduleGather(modeId)
	end
end

return MatchCoordinator
