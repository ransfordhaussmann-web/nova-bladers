local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

local padCooldown = {}

local function getDefaultModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function joinQueueForPlayer(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = getDefaultModeId()
	end
	MatchmakingService.joinQueue(player, modeId)
	if HubService.markQueued then
		HubService.markQueued(player, modeId)
	end
end

local function connectModePads()
	local hub = workspace:WaitForChild("Hub", 30)
	if not hub then
		return
	end

	for _, child in hub:GetChildren() do
		local modeId = child.Name:match("^ModePad_(.+)$")
		if modeId and MatchmakingConfig.MODES[modeId] then
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
				if padCooldown[player] and now - padCooldown[player] < MatchmakingConfig.PAD_TOUCH_COOLDOWN then
					return
				end
				padCooldown[player] = now

				joinQueueForPlayer(player, modeId)
			end)
		end
	end
end

MatchmakingService.configure({
	onQueueUpdate = function(player, payload)
		Remotes.QueueUpdate:FireClient(player, payload)
	end,
	onQueueLeft = function(player)
		Remotes.QueueUpdate:FireClient(player, { status = "left" })
	end,
	onMatchReady = function(playerList, modeId)
		Bindables.MatchReady:Fire(playerList, modeId)
	end,
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	joinQueueForPlayer(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
	if HubService.getPhase(player) == "queued" then
		HubService.returnPlayerToHub(player)
	end
end)

task.spawn(connectModePads)

task.spawn(function()
	while true do
		task.wait(MatchmakingConfig.TICK_INTERVAL)
		MatchmakingService.tick()
	end
end)

print("[MatchmakingManager] Queue ready — Mode-Pads, Portal, Lobby-Button")

return {
	joinQueue = joinQueueForPlayer,
	leaveQueue = function(player)
		MatchmakingService.leaveQueue(player)
	end,
	getDefaultModeId = getDefaultModeId,
}
