local MatchState = {
	busy = false,
}

function MatchState.setBusy(busy)
	MatchState.busy = busy == true
end

function MatchState.isBusy()
	return MatchState.busy
end

return MatchState
