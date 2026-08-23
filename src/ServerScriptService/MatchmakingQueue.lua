--[[
	MatchmakingQueue — groups arena players by preferred mode and starts matches
	when minimum players are met or max wait expires.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes = RemotesSetup.ensure()

local MatchmakingQueue = {}

local entries = {} -- { player, modeId, joinedAt }
local onReadyCallback = nil

local MODE_LABELS = {
	training = "Training",
	pvp = "1v1 PvP",
	ffa = "FFA",
}

local function getRule(modeId)
	return HubConfig.QUEUE_RULES[modeId] or HubConfig.QUEUE_RULES.training
end

local function findEntry(player)
	for i, entry in entries do
		if entry.player == player then
			return entry, i
		end
	end
	return nil
end

local function modeCounts()
	local counts = { training = 0, pvp = 0, ffa = 0 }
	for _, entry in entries do
		counts[entry.modeId] = (counts[entry.modeId] or 0) + 1
	end
	return counts
end

local function buildStatus(player)
	local entry = findEntry(player)
	if not entry then
		return { inQueue = false }
	end

	local rule = getRule(entry.modeId)
	local counts = modeCounts()
	local waiting = counts[entry.modeId] or 0
	local position = 1
	for _, other in entries do
		if other.modeId == entry.modeId and other.joinedAt < entry.joinedAt then
			position += 1
		end
	end

	local elapsed = os.clock() - entry.joinedAt
	local timeLeft = math.max(0, math.ceil(rule.maxWait - elapsed))

	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = MODE_LABELS[entry.modeId] or entry.modeId,
		waiting = waiting,
		needed = rule.min,
		position = position,
		timeLeft = timeLeft,
	}
end

function MatchmakingQueue.broadcast()
	for _, entry in entries do
		if entry.player.Parent then
			Remotes.QueueUpdate:FireClient(entry.player, buildStatus(entry.player))
		end
	end
end

function MatchmakingQueue.enqueue(player, modeId)
	MatchmakingQueue.dequeue(player)

	table.insert(entries, {
		player = player,
		modeId = modeId or "training",
		joinedAt = os.clock(),
	})

	MatchmakingQueue.broadcast()
end

function MatchmakingQueue.dequeue(player)
	local _, index = findEntry(player)
	if index then
		table.remove(entries, index)
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		end
		MatchmakingQueue.broadcast()
	end
end

function MatchmakingQueue.setMode(player, modeId)
	local entry = findEntry(player)
	if not entry or not modeId then
		return
	end
	entry.modeId = modeId
	entry.joinedAt = os.clock()
	MatchmakingQueue.broadcast()
end

function MatchmakingQueue.isQueued(player)
	return findEntry(player) ~= nil
end

function MatchmakingQueue.onReady(callback)
	onReadyCallback = callback
end

local function collectReadyGroup(modeId)
	local rule = getRule(modeId)
	local group = {}
	local oldestJoin = nil

	for _, entry in entries do
		if entry.modeId == modeId and entry.player.Parent then
			table.insert(group, entry.player)
			if not oldestJoin or entry.joinedAt < oldestJoin then
				oldestJoin = entry.joinedAt
			end
		end
	end

	if #group == 0 then
		return nil
	end

	local waited = os.clock() - oldestJoin
	if #group >= rule.min or waited >= rule.maxWait then
		if #group >= rule.min then
			return group
		end
		-- Timeout with fewer players — downgrade to playable size
		if modeId == "ffa" and #group >= HubConfig.QUEUE_RULES.pvp.min then
			return group
		end
		if modeId == "pvp" or modeId == "ffa" then
			return group -- start with whoever waited (training/pvp fallback in GameManager)
		end
		return group
	end

	return nil
end

function MatchmakingQueue.tryStartMatch()
	if not onReadyCallback then
		return
	end

	for _, modeId in { "ffa", "pvp", "training" } do
		local group = collectReadyGroup(modeId)
		if group then
			for _, player in group do
				MatchmakingQueue.dequeue(player)
			end
			onReadyCallback(group)
			return
		end
	end
end

function MatchmakingQueue.start()
	task.spawn(function()
		while true do
			task.wait(HubConfig.QUEUE_TICK)
			-- Drop disconnected players
			for i = #entries, 1, -1 do
				if not entries[i].player.Parent then
					table.remove(entries, i)
				end
			end
			MatchmakingQueue.tryStartMatch()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingQueue.dequeue(player)
	end)
end

return MatchmakingQueue
