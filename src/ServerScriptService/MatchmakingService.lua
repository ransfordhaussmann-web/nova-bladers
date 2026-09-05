local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BeyConfig = require(ReplicatedStorage.NovaBladers.BeyConfig)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local remotes = nil
local startMatchBindable = nil

local function getModeLabel(mode, count, needed)
	if mode == "training" then
		return "Training — startet gleich"
	elseif mode == "pvp" then
		return string.format("1v1 Warteschlange: %d/%d", count, needed)
	end
	return string.format("FFA Warteschlange: %d/%d", count, needed)
end

local function buildStatusPayload()
	local summary = {}
	for mode, list in queues do
		local needed = 1
		if mode == "pvp" then
			needed = BeyConfig.MATCHMAKING.MIN_PVP
		elseif mode == "ffa" then
			needed = BeyConfig.MATCHMAKING.MIN_FFA
		end
		summary[mode] = {
			count = #list,
			needed = needed,
			label = getModeLabel(mode, #list, needed),
		}
	end
	return summary
end

function MatchmakingService.broadcastStatus()
	if not remotes then
		return
	end

	local payload = buildStatusPayload()
	for mode, list in queues do
		for _, player in list do
			if player.Parent then
				remotes.MatchmakingStatus:FireClient(player, {
					inQueue = true,
					mode = mode,
					queues = payload,
				})
			end
		end
	end

	for _, player in Players:GetPlayers() do
		if not playerQueue[player] and player.Parent then
			remotes.MatchmakingStatus:FireClient(player, {
				inQueue = false,
				queues = payload,
			})
		end
	end
end

function MatchmakingService.removeFromQueue(player)
	local mode = playerQueue[player]
	if not mode then
		return
	end

	local list = queues[mode]
	for i, queued in list do
		if queued == player then
			table.remove(list, i)
			break
		end
	end
	playerQueue[player] = nil

	if remotes and player.Parent then
		remotes.MatchmakingStatus:FireClient(player, {
			inQueue = false,
			queues = buildStatusPayload(),
		})
	end
	MatchmakingService.broadcastStatus()
end

local function popPlayers(mode, count)
	local list = queues[mode]
	local picked = {}
	for _ = 1, math.min(count, #list) do
		local player = table.remove(list, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(picked, player)
		end
	end
	return picked
end

local function startMatchForPlayers(playerList)
	if #playerList == 0 or not startMatchBindable then
		return
	end
	for _, player in playerList do
		if HubService.getPhase(player) ~= "arena" then
			HubService.enterArena(player)
		end
	end
	startMatchBindable:Fire(playerList)
	MatchmakingService.broadcastStatus()
end

local function tryStartMatches()
	local cfg = BeyConfig.MATCHMAKING

	while #queues.ffa >= cfg.MIN_FFA do
		local count = math.min(#queues.ffa, cfg.MAX_FFA)
		local players = popPlayers("ffa", count)
		startMatchForPlayers(players)
	end

	while #queues.pvp >= cfg.MIN_PVP do
		local players = popPlayers("pvp", cfg.MIN_PVP)
		startMatchForPlayers(players)
	end
end

function MatchmakingService.joinQueue(player, mode)
	if mode ~= "training" and mode ~= "pvp" and mode ~= "ffa" then
		return
	end
	if HubService.getPhase(player) == "arena" then
		return
	end

	MatchmakingService.removeFromQueue(player)

	table.insert(queues[mode], player)
	playerQueue[player] = mode
	MatchmakingService.broadcastStatus()

	if mode == "training" then
		task.delay(BeyConfig.MATCHMAKING.SOLO_TRAINING_DELAY, function()
			if playerQueue[player] ~= "training" then
				return
			end
			local players = popPlayers("training", 1)
			if players[1] == player then
				startMatchForPlayers(players)
			end
		end)
	else
		tryStartMatches()
	end
end

function MatchmakingService.init(remoteFolder, startMatchEvent)
	remotes = remoteFolder
	startMatchBindable = startMatchEvent
end

return MatchmakingService
