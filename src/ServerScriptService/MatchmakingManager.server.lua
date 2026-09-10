local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local padCooldowns = {}

local function buildPlayerUpdate(player)
	local entry = MatchmakingService.getPlayerQueue(player)
	if not entry then
		return {
			inQueue = false,
			arenaBusy = MatchmakingService.isArenaBusy(),
		}
	end

	local snapshot = MatchmakingService.getQueueSnapshot(entry.modeId)
	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = snapshot.label,
		position = snapshot.count,
		players = snapshot.players,
		minPlayers = snapshot.minPlayers,
		maxPlayers = snapshot.maxPlayers,
		arenaBusy = snapshot.arenaBusy,
		pending = snapshot.arenaBusy,
	}
end

local function sendQueueUpdate(player)
	if not player.Parent then
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildPlayerUpdate(player))
end

local function broadcastQueueForMode(modeId)
	local snapshot = MatchmakingService.getQueueSnapshot(modeId)
	for _, player in Players:GetPlayers() do
		local entry = MatchmakingService.getPlayerQueue(player)
		if entry and entry.modeId == modeId then
			Remotes.QueueUpdate:FireClient(player, {
				inQueue = true,
				modeId = modeId,
				modeLabel = snapshot.label,
				position = snapshot.count,
				players = snapshot.players,
				minPlayers = snapshot.minPlayers,
				maxPlayers = snapshot.maxPlayers,
				arenaBusy = snapshot.arenaBusy,
				pending = snapshot.arenaBusy,
			})
		end
	end
end

local function onQueueChanged(player, modeId)
	sendQueueUpdate(player)
	broadcastQueueForMode(modeId)
end

local function onMatchReady(players, modeId)
	MatchmakingService.setArenaBusy(true)
	for _, player in players do
		sendQueueUpdate(player)
	end

	Bindables.MatchReady:Fire(players, modeId)
end

MatchmakingService.setCallbacks({
	onQueueChanged = onQueueChanged,
	onMatchReady = onMatchReady,
	onArenaFreed = function()
		for _, player in Players:GetPlayers() do
			sendQueueUpdate(player)
		end
	end,
})

local function joinQueue(player, modeId)
	if HubService.getPhase(player) == "arena" then
		return
	end

	local ok = MatchmakingService.joinQueue(player, modeId)
	if ok then
		HubService.setQueued(player, modeId)
	end
end

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end
	joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
	HubService.clearQueued(player)
	sendQueueUpdate(player)
end)

local function setupModePads()
	local hub = workspace:WaitForChild("Hub", 30)
	if not hub then
		return
	end

	for _, child in hub:GetChildren() do
		if child.Name:match("^ModePad_") then
			local modeId = child.Name:gsub("^ModePad_", "")
			if MatchmakingConfig.getMode(modeId) then
				child.Touched:Connect(function(hit)
					local character = hit.Parent
					if not character then
						return
					end
					local humanoid = character:FindFirstChildOfClass("Humanoid")
					if not humanoid then
						return
					end
					local player = Players:GetPlayerFromCharacter(character)
					if not player then
						return
					end

					local now = os.clock()
					local last = padCooldowns[player]
					if last and now - last < MatchmakingConfig.PAD_COOLDOWN then
						return
					end
					padCooldowns[player] = now

					joinQueue(player, modeId)
				end)
			end
		end
	end
end

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.onArenaFreed()
end)

Players.PlayerRemoving:Connect(function(player)
	padCooldowns[player] = nil
	MatchmakingService.onPlayerRemoving(player)
end)

task.defer(setupModePads)

print("[MatchmakingManager] Queue system ready")
