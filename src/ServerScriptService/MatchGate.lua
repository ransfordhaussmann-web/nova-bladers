--[[
	MatchGate — shared arena availability flag between GameManager and MatchmakingService.
]]

local MatchGate = {
	_available = true,
}

function MatchGate.setAvailable(available)
	MatchGate._available = available
end

function MatchGate.isAvailable()
	return MatchGate._available
end

return MatchGate
