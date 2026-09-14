--[[
	GameMatchState — tracks whether the arena is occupied and holds pending rosters.
]]

local GameMatchState = {
	arenaBusy = false,
	pendingMatches = {},
}

function GameMatchState.isArenaBusy()
	return GameMatchState.arenaBusy
end

function GameMatchState.setArenaBusy(busy)
	GameMatchState.arenaBusy = busy
end

function GameMatchState.enqueuePending(roster, modeId)
	table.insert(GameMatchState.pendingMatches, {
		players = roster,
		modeId = modeId,
	})
end

function GameMatchState.dequeuePending()
	return table.remove(GameMatchState.pendingMatches, 1)
end

function GameMatchState.hasPending()
	return #GameMatchState.pendingMatches > 0
end

return GameMatchState
