local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local playerState = {}

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA (" .. playerCount .. " Spieler)"
end

local function buildLobbyPayload(player, opts)
	opts = opts or {}
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local inHub = opts.inHub ~= false
	local inArena = opts.inArena == true

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = inHub,
		inArena = inArena,
		showPanel = opts.showPanel == true,
	}
end

local function sendLobbyReady(player, opts)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, opts))
end

local function getNearestZone(position)
	local origin = HubConfig.HUB_ORIGIN
	local bestZone
	local bestDist = HubConfig.INTERACT_DISTANCE

	for _, zone in HubConfig.ZONES do
		local worldPos = origin + zone.position
		local dist = (Vector3.new(position.X, worldPos.Y, position.Z) - worldPos).Magnitude
		if dist <= bestDist then
			bestDist = dist
			bestZone = zone
		end
	end

	return bestZone
end

local function teleportToHub(player)
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	hrp.CFrame = HubWorldBuilder.getSpawnCFrame()
end

function HubWorldManager.sendToHub(player, showPanel)
	local state = playerState[player]
	if not state then return end
	state.inArena = false
	state.inHub = true
	teleportToHub(player)
	sendLobbyReady(player, { inHub = true, showPanel = showPanel == true })
	remotes.HubZoneHint:FireClient(player, { zone = nil })
end

function HubWorldManager.sendToArena(player)
	local state = playerState[player]
	if state then
		state.inArena = true
		state.inHub = false
	end
	sendLobbyReady(player, { inHub = false, inArena = true })
	remotes.HubZoneHint:FireClient(player, { zone = nil })
end

local function handleZoneAction(player, zone)
	if not zone then return end

	if zone.action == "enterArena" then
		HubWorldManager.sendToArena(player)
	elseif zone.action == "openBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zone.action == "showLobby" then
		sendLobbyReady(player, { inHub = true, showPanel = true })
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	HubWorldBuilder.build()

	Players.PlayerAdded:Connect(function(player)
		playerState[player] = { inHub = true, inArena = false, currentZone = nil }
		PlayerDataManager.load(player)
		local data = PlayerDataManager.get(player)
		LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

		player.CharacterAdded:Connect(function()
			task.wait(0.1)
			local state = playerState[player]
			if state and state.inHub and not state.inArena then
				teleportToHub(player)
			end
		end)

		task.defer(function()
			sendLobbyReady(player, { inHub = true, showPanel = false })
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
		playerState[player] = nil
	end)

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.sendToArena(player)
	end)

	remotes.HubInteract.OnServerEvent:Connect(function(player)
		local character = player.Character
		if not character then return end
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not hrp then return end

		local state = playerState[player]
		if not state or state.inArena then return end

		local zone = getNearestZone(hrp.Position)
		handleZoneAction(player, zone)
	end)

	task.spawn(function()
		while true do
			task.wait(HubConfig.ZONE_CHECK_INTERVAL)
			for _, player in Players:GetPlayers() do
				local state = playerState[player]
				if not state or state.inArena then continue end

				local character = player.Character
				local hrp = character and character:FindFirstChild("HumanoidRootPart")
				if not hrp then continue end

				local zone = getNearestZone(hrp.Position)
				if zone ~= state.currentZone then
					state.currentZone = zone
					if zone then
						remotes.HubZoneHint:FireClient(player, {
							zone = zone.id,
							name = zone.name,
							hint = zone.hint,
						})
					else
						remotes.HubZoneHint:FireClient(player, { zone = nil })
					end
				end
			end
		end
	end)
end

_G.NovaBladersReturnToHub = function(player)
	HubWorldManager.sendToHub(player, false)
end

return HubWorldManager
