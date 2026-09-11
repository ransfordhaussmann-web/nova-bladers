local MatchState = {
	arenaBusy = false,
}

function MatchState.setBusy(busy)
	MatchState.arenaBusy = busy
end

function MatchState.isBusy()
	return MatchState.arenaBusy
end

return MatchState
