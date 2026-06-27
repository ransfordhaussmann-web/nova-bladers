local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}
HubWorldManager._inArena = {}
HubWorldManager._portalCooldown = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.CFrame = CFrame.new(props.position)
	part.Color = props.color or Color3.fromRGB(200, 200, 200)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "HubPart"
	part.Parent = props.parent
	return part
end

local function makeLabel(parent, text, offsetY)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, offsetY or 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextSize = 18
	label.Text = text
	label.Parent = billboard
end

function HubWorldManager.buildWorld()
	local existing = Workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then return existing end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = Workspace

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.Parent = hub

	makePart({
		name = "Floor",
		parent = hub,
		position = Vector3.new(0, 0.5, 0),
		size = HubConfig.FLOOR_SIZE,
		color = HubConfig.FLOOR_COLOR,
		material = HubConfig.FLOOR_MATERIAL,
	})

	local rimColor = Color3.fromRGB(60, 70, 100)
	for _, offset in {
		Vector3.new(0, 2, HubConfig.FLOOR_SIZE.Z / 2),
		Vector3.new(0, 2, -HubConfig.FLOOR_SIZE.Z / 2),
		Vector3.new(HubConfig.FLOOR_SIZE.X / 2, 2, 0),
		Vector3.new(-HubConfig.FLOOR_SIZE.X / 2, 2, 0),
	} do
		local isZ = offset.Z ~= 0
		makePart({
			name = "Rim",
			parent = hub,
			position = offset,
			size = isZ and Vector3.new(HubConfig.FLOOR_SIZE.X, 4, 2) or Vector3.new(2, 4, HubConfig.FLOOR_SIZE.Z),
			color = rimColor,
		})
	end

	local function buildStation(key, interactName)
		local cfg = HubConfig[key]
		local station = makePart({
			name = key,
			parent = hub,
			position = cfg.position,
			size = cfg.size,
			color = cfg.color,
		})
		station:SetAttribute("Interact", interactName)
		makeLabel(station, cfg.label, cfg.size.Y / 2 + 2)
		return station
	end

	buildStation("ARENA_PORTAL", "EnterArena")
	buildStation("BEY_STATION", "OpenBeySelect")
	buildStation("STATS_KIOSK", "ShowStats")
	buildStation("LEADERBOARD_BOARD", "ShowLeaderboard")

	local light = Instance.new("PointLight")
	light.Brightness = 1.2
	light.Range = 60
	light.Parent = spawn

	return hub
end

function HubWorldManager.getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

function HubWorldManager.buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	local arenaPlayers = 0
	for plr in Players:GetPlayers() do
		if HubWorldManager._inArena[plr] then
			arenaPlayers += 1
		end
	end

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = HubWorldManager.getModeLabel(math.max(1, arenaPlayers)),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = true,
	}
end

function HubWorldManager.sendToHub(player)
	HubWorldManager._inArena[player] = nil
	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		character:PivotTo(CFrame.new(HubConfig.SPAWN, HubConfig.SPAWN_LOOK))
	end
	local remotes = RemotesSetup.ensure()
	remotes.HubState:FireClient(player, { inHub = true })
	remotes.LobbyReady:FireClient(player, HubWorldManager.buildLobbyPayload(player))
end

function HubWorldManager.sendToArena(player)
	if HubWorldManager._portalCooldown[player] then return end
	HubWorldManager._portalCooldown[player] = true
	task.delay(HubConfig.PORTAL_COOLDOWN, function()
		HubWorldManager._portalCooldown[player] = nil
	end)

	HubWorldManager._inArena[player] = true
	local remotes = RemotesSetup.ensure()
	remotes.HubState:FireClient(player, { inHub = false })
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	player.CharacterAdded:Connect(function()
		if not HubWorldManager._inArena[player] then
			task.defer(function()
				HubWorldManager.sendToHub(player)
			end)
		end
	end)
	if player.Character then
		HubWorldManager.sendToHub(player)
	end
end

function HubWorldManager.onPlayerRemoving(player)
	HubWorldManager._inArena[player] = nil
	HubWorldManager._portalCooldown[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.sendToHub(player)
end

function HubWorldManager.init()
	RemotesSetup.ensure()
	HubWorldManager.buildWorld()

	local remotes = ReplicatedStorage.NovaBladers.Remotes
	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.sendToArena(player)
	end)

	remotes.RefreshHubStats.OnServerEvent:Connect(function(player)
		if HubWorldManager._inArena[player] then return end
		remotes.LobbyReady:FireClient(player, HubWorldManager.buildLobbyPayload(player))
	end)

	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)
	Players.PlayerRemoving:Connect(HubWorldManager.onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player)
	end
end

return HubWorldManager
