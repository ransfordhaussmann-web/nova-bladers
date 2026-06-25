local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(script.Parent.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local hubFolder
local remotes
local inArena = {}

local function ensureRemotes()
	local root = ReplicatedStorage:FindFirstChild("NovaBladers")
	if not root then
		root = Instance.new("Folder")
		root.Name = "NovaBladers"
		root.Parent = ReplicatedStorage
	end

	local folder = root:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = root
	end

	local names = { "LobbyReady", "EnterArena", "OpenBeySelect", "ReturnToHub", "HubZoneHint" }
	for _, name in names do
		if not folder:FindFirstChild(name) then
			local remote
			if name == "EnterArena" or name == "OpenBeySelect" or name == "ReturnToHub" then
				remote = Instance.new("RemoteEvent")
			else
				remote = Instance.new("RemoteEvent")
			end
			remote.Name = name
			remote.Parent = folder
		end
	end

	return folder
end

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

local function buildPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
	}
end

local function teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = CFrame.new(HubConfig.SPAWN_POSITION)
	inArena[player] = nil
end

function HubWorldManager.sendHubReady(player)
	if not remotes then return end
	remotes.LobbyReady:FireClient(player, buildPayload(player))
end

function HubWorldManager.returnToHub(player)
	teleportToHub(player)
	HubWorldManager.sendHubReady(player)
	if remotes then
		remotes.ReturnToHub:FireClient(player)
	end
end

local function onEnterArena(player)
	if inArena[player] then return end
	inArena[player] = true
	-- Arena teleport handled by GameManager when present; remote notifies clients.
end

local function onOpenBeySelect(player)
	if remotes then
		remotes.OpenBeySelect:FireClient(player)
	end
end

local function connectZonePrompts()
	if not hubFolder then return end
	local zones = hubFolder:FindFirstChild("Zones")
	if not zones then return end

	for _, zoneFolder in zones:GetChildren() do
		local trigger = zoneFolder:FindFirstChild("Trigger")
		if not trigger then continue end
		local prompt = trigger:FindFirstChildOfClass("ProximityPrompt")
		if not prompt then continue end

		local zoneId = trigger:GetAttribute("ZoneId")
		local zoneConfig = HubConfig.ZONES[zoneId]
		if not zoneConfig then continue end

		prompt.Triggered:Connect(function(player)
			remotes.HubZoneHint:FireClient(player, {
				zoneId = zoneId,
				label = zoneConfig.label,
				hint = zoneConfig.hint,
			})

			local action = trigger:GetAttribute("ZoneAction")
			if action == "EnterArena" then
				onEnterArena(player)
				remotes.EnterArena:FireClient(player)
			elseif action == "OpenBeySelect" then
				onOpenBeySelect(player)
			elseif action == "ShowStats" then
				HubWorldManager.sendHubReady(player)
			end
		end)
	end
end

function HubWorldManager.init()
	if not HubConfig.USE_3D_HUB then
		return
	end

	remotes = ensureRemotes()
	hubFolder = HubWorldBuilder.build()
	connectZonePrompts()

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		local data = PlayerDataManager.get(player)
		LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

		player.CharacterAdded:Connect(function()
			task.defer(function()
				if not inArena[player] then
					teleportToHub(player)
					HubWorldManager.sendHubReady(player)
				end
			end)
		end)

		if player.Character then
			teleportToHub(player)
			HubWorldManager.sendHubReady(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
		inArena[player] = nil
	end)

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		onEnterArena(player)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	_G.NovaBladersReturnToHub = HubWorldManager.returnToHub

	for _, player in Players:GetPlayers() do
		if not PlayerDataManager.get(player) then
			PlayerDataManager.load(player)
		end
		teleportToHub(player)
		HubWorldManager.sendHubReady(player)
	end
end

return HubWorldManager
