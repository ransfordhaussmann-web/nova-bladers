--[[
	MatchQueue — groups arena players and starts matches when requirements are met.
]]

local Players = game:GetService("Players")

local MatchQueue = {}

local MODE_MIN = {
	training = 1,
	pvp = 2,
	ffa = 3,
}

local MODE_LABELS = {
	training = "Training",
	pvp = "1v1 PvP",
	ffa = "FFA",
	auto = "Auto",
}

local entries = {}
local preferences = {}
local remotes = nil
local maxWait = 30
local onMatchReady = nil
local tickRunning = false

local function getPreference(player)
	return preferences[player] or "auto"
end

local function removeEntry(player)
	for i = #entries, 1, -1 do
		if entries[i].player == player then
			table.remove(entries, i)
		end
	end
end

local function resolveMode(queueSize, preferMode)
	if preferMode ~= "auto" and queueSize >= MODE_MIN[preferMode] then
		return preferMode
	end
	if queueSize >= MODE_MIN.ffa then
		return "ffa"
	elseif queueSize >= MODE_MIN.pvp then
		return "pvp"
	end
	return "training"
end

local function degradeMode(queueSize)
	if queueSize >= MODE_MIN.ffa then
		return "ffa"
	elseif queueSize >= MODE_MIN.pvp then
		return "pvp"
	end
	return "training"
end

local function buildStatus(player)
	local position = 0
	for i, entry in entries do
		if entry.player == player then
			position = i
			break
		end
	end

	local queueSize = #entries
	local pref = getPreference(player)
	local targetMode = resolveMode(queueSize, pref)
	local required = MODE_MIN[targetMode]
	local oldestWait = 0
	if entries[1] then
		oldestWait = os.clock() - entries[1].joinedAt
	end

	return {
		inQueue = position > 0,
		position = position,
		queueSize = queueSize,
		mode = targetMode,
		modeLabel = MODE_LABELS[targetMode],
		preferredMode = pref,
		preferredLabel = MODE_LABELS[pref],
		required = required,
		waiting = queueSize < required,
		maxWait = maxWait,
		elapsed = math.floor(oldestWait),
	}
end

function MatchQueue.broadcast()
	if not remotes or not remotes.MatchQueueUpdate then
		return
	end
	for _, entry in entries do
		local player = entry.player
		if player.Parent then
			remotes.MatchQueueUpdate:FireClient(player, buildStatus(player))
		end
	end
end

function MatchQueue.tryStart()
	if #entries == 0 or not onMatchReady then
		return
	end

	local oldestWait = os.clock() - entries[1].joinedAt
	local forceStart = oldestWait >= maxWait

	local pref = getPreference(entries[1].player)
	local targetMode = resolveMode(#entries, pref)
	local required = MODE_MIN[targetMode]

	if forceStart and #entries < required then
		targetMode = degradeMode(#entries)
		required = MODE_MIN[targetMode]
	end

	if #entries < required and not forceStart then
		return
	end

	local players = {}
	local take = targetMode == "ffa" and #entries or required
	for _ = 1, take do
		local entry = table.remove(entries, 1)
		if entry and entry.player.Parent then
			table.insert(players, entry.player)
		end
	end

	if #players == 0 then
		return
	end

	onMatchReady(players, targetMode)
	MatchQueue.broadcast()

	if #entries > 0 then
		MatchQueue.tryStart()
	end
end

function MatchQueue.init(remotesFolder, config)
	remotes = remotesFolder
	maxWait = (config and config.QUEUE_MAX_WAIT) or 30

	if tickRunning then
		return
	end
	tickRunning = true

	task.spawn(function()
		while true do
			task.wait(1)
			if #entries > 0 then
				MatchQueue.broadcast()
				MatchQueue.tryStart()
			end
		end
	end)
end

function MatchQueue.setOnMatchReady(callback)
	onMatchReady = callback
end

function MatchQueue.setPreference(player, modeId)
	if modeId ~= "auto" and not MODE_MIN[modeId] then
		return
	end
	preferences[player] = modeId
	if MatchQueue.isQueued(player) then
		MatchQueue.broadcast()
		MatchQueue.tryStart()
	end
end

function MatchQueue.getPreference(player)
	return getPreference(player)
end

function MatchQueue.join(player)
	if not player.Parent then
		return
	end
	removeEntry(player)
	table.insert(entries, {
		player = player,
		joinedAt = os.clock(),
	})
	MatchQueue.broadcast()
	MatchQueue.tryStart()
end

function MatchQueue.leave(player)
	if not MatchQueue.isQueued(player) then
		return
	end
	removeEntry(player)
	MatchQueue.broadcast()
end

function MatchQueue.isQueued(player)
	for _, entry in entries do
		if entry.player == player then
			return true
		end
	end
	return false
end

function MatchQueue.clearPlayer(player)
	removeEntry(player)
	preferences[player] = nil
end

Players.PlayerRemoving:Connect(function(player)
	MatchQueue.clearPlayer(player)
end)

return MatchQueue
