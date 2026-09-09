local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchCoordinator = {}

local bindables

function MatchCoordinator.configure(options)
	bindables = options.bindables
end

function MatchCoordinator.startMatch(players, modeId)
	if MatchStateService.isBusy() then
		return
	end

	MatchStateService.setBusy(true)

	for _, player in players do
		HubService.leaveHubForMatch(player, modeId)
	end

	if bindables and bindables.MatchReady then
		bindables.MatchReady:Fire(players, modeId)
	end
end

function MatchCoordinator.onMatchEnded()
	MatchStateService.setBusy(false)
	MatchStateService.notifyArenaIdle()
end

function MatchCoordinator.resolveAutoMode(playerCount)
	if playerCount >= MatchmakingConfig.MODES.ffa.minPlayers then
		return "ffa"
	elseif playerCount >= MatchmakingConfig.MODES.pvp.minPlayers then
		return "pvp"
	end
	return "training"
end

return MatchCoordinator
