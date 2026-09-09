local MatchGate = {}
MatchGate.__index = MatchGate

function MatchGate.new(options)
	local self = setmetatable({}, MatchGate)
	self.isBusy = options.isBusy
	self.startMatch = options.startMatch
	self.pending = {}
	return self
end

function MatchGate:requestMatch(players, modeId)
	if self.isBusy() then
		table.insert(self.pending, {
			players = players,
			modeId = modeId,
		})
		return false
	end

	self.startMatch(players, modeId)
	return true
end

function MatchGate:onMatchEnded()
	if #self.pending == 0 or self.isBusy() then
		return
	end

	local nextMatch = table.remove(self.pending, 1)
	self.startMatch(nextMatch.players, nextMatch.modeId)
end

function MatchGate:getPendingCount()
	return #self.pending
end

return MatchGate
