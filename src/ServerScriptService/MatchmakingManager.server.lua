local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)
local MatchmakingService = require(script.Parent.MatchmakingService)

local Remotes, Bindables = RemotesSetup.ensure()
local EnterArena = Bindables.EnterArena
local MatchReady = Bindables.MatchReady
local MatchEnded = Bindables.MatchEnded

local padCooldowns = {}

local function leaveHubForArena(player)
	if HubService.getPhase(player) == "arena" then
		return
	end
	HubService.leaveHubForArena(player)
end

local function joinQueue(player, modeId)
	if HubService.getPhase(player) == "arena" then
		return
	end

	local ok, reason = MatchmakingService.joinQueue(player, modeId)
	if not ok and reason == "queue_full" then
		Remotes.QueueUpdate:FireClient(player, {
			error = "queue_full",
			modeId = modeId,
		})
	end
end

MatchmakingService.setBroadcast(function(player, payload)
	Remotes.QueueUpdate:FireClient(player, payload)
end)

MatchmakingService.setMatchReadyCallback(function(match)
	for _, player in match.players do
		leaveHubForArena(player)
	end
	MatchReady:Fire(match)
end)

MatchEnded.Event:Connect(function()
	MatchmakingService.setArenaBusy(false)
end)

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingConfig.getRecommendedMode(#Players:GetPlayers())
	end
	joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

EnterArena.Event:Connect(function(player)
	local modeId = MatchmakingConfig.getRecommendedMode(#Players:GetPlayers())
	joinQueue(player, modeId)
end)

local function waitForHubPads()
	local hub = workspace:WaitForChild("Hub", 30)
	if not hub then
		return
	end

	for _, child in hub:GetChildren() do
		if child.Name:match("^ModePad_") then
			local modeId = child.Name:gsub("^ModePad_", "")
			local mode = MatchmakingConfig.getMode(modeId)
			if mode then
				child.Touched:Connect(function(hit)
					local character = hit.Parent
					if not character then
						return
					end
					local player = Players:GetPlayerFromCharacter(character)
					if not player then
						return
					end

					local now = os.clock()
					local lastTouch = padCooldowns[player]
					if lastTouch and now - lastTouch < MatchmakingConfig.PAD_TOUCH_COOLDOWN then
						return
					end
					padCooldowns[player] = now

					joinQueue(player, modeId)
				end)
			end
		end
	end
end

task.defer(waitForHubPads)

Players.PlayerRemoving:Connect(function(player)
	padCooldowns[player] = nil
	MatchmakingService.onPlayerRemoving(player)
end)

print("[MatchmakingManager] Queue system ready")
