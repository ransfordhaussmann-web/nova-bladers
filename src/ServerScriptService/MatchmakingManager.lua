local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubService = require(script.Parent.HubService)
local MatchmakingService = require(script.Parent.MatchmakingService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingManager = {}

local Remotes, Bindables
local initialized = false

local function ensureRemotes()
	if not Remotes then
		Remotes, Bindables = RemotesSetup.ensure()
	end
	return Remotes, Bindables
end

local function joinQueue(player, modeId)
	if HubService.getPhase(player) ~= "hub" then
		return
	end
	MatchmakingService.join(player, modeId)
end

function MatchmakingManager.init()
	if initialized then
		return
	end
	initialized = true
	local remotes, bindables = ensureRemotes()

	MatchmakingService.onQueueUpdate(function(player, payload)
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, payload)
		end
	end)

	MatchmakingService.onMatchReady(function(payload)
		bindables.MatchReady:Fire(payload)
	end)

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.resolvePortalMode()
		end
		joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leave(player)
	end)

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		joinQueue(player, MatchmakingService.resolvePortalMode())
	end)

	bindables.MatchStarted.Event:Connect(function()
		MatchmakingService.setArenaBusy(true)
	end)

	bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.setArenaBusy(false)
	end)
end

function MatchmakingManager.registerHubTriggers(hub)
	MatchmakingManager.init()
	local _remotes = ensureRemotes()

	hub.portalPrompt.Triggered:Connect(function(player)
		joinQueue(player, MatchmakingService.resolvePortalMode())
	end)

	for _, pad in hub.modePads do
		if pad.prompt then
			pad.prompt.Triggered:Connect(function(player)
				joinQueue(player, pad.config.id)
			end)
		end
	end
end

return MatchmakingManager
