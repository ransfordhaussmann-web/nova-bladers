local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchStateService = {}

local arenaBusy = false
local cooldownUntil = 0

function MatchStateService.isBusy()
	if arenaBusy then
		return true
	end
	return os.clock() < cooldownUntil
end

function MatchStateService.setMatchActive(active)
	arenaBusy = active
	if not active then
		cooldownUntil = os.clock() + MatchmakingConfig.ARENA_COOLDOWN
	end
end

return MatchStateService
