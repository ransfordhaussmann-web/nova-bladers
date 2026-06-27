local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local Remotes = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local hubBuilt = false
local playersInHub = {}

local function getCharacterRoot(player)
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

local function teleportPlayer(player, position)
	local root = getCharacterRoot(player)
	if root then
		root.CFrame = CFrame.new(position)
	end
end

local function makePart(props)
	local part = Instance.new("Part")
	part.Name = props.Name
	part.Size = props.Size
	part.Position = props.Position
	part.Anchored = true
	part.Color = props.Color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Transparency = props.Transparency or 0
	part.CanCollide = if props.CanCollide == nil then true else props.CanCollide
	part.Parent = props.Parent
	return part
end

local function addBillboard(parent, text)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(200, 48)
	gui.StudsOffset = Vector3.new(0, parent.Size.Y * 0.5 + 2, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.TextSize = 18
	label.Text = text
	label.Parent = gui
end

local function addProximityPrompt(parent, actionText, zoneId)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HubPrompt"
	prompt.ActionText = actionText
	prompt.ObjectText = parent.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("HubZone", zoneId)
	prompt.Parent = parent
	return prompt
end

function HubWorldManager.buildHubWorld()
	if hubBuilt then
		return workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = workspace

	local origin = HubConfig.HUB_ORIGIN
	local floorSize = HubConfig.FLOOR_SIZE

	makePart({
		Name = "Floor",
		Size = floorSize,
		Position = origin + Vector3.new(0, -floorSize.Y * 0.5, 0),
		Color = HubConfig.COLORS.Floor,
		Parent = hub,
	})

	local rimHeight = 3
	local rimThickness = 2
	local halfX = floorSize.X * 0.5
	local halfZ = floorSize.Z * 0.5

	local rims = {
		{ Vector3.new(0, rimHeight * 0.5, halfZ + rimThickness * 0.5), Vector3.new(floorSize.X + rimThickness * 2, rimHeight, rimThickness) },
		{ Vector3.new(0, rimHeight * 0.5, -halfZ - rimThickness * 0.5), Vector3.new(floorSize.X + rimThickness * 2, rimHeight, rimThickness) },
		{ Vector3.new(halfX + rimThickness * 0.5, rimHeight * 0.5, 0), Vector3.new(rimThickness, rimHeight, floorSize.Z) },
		{ Vector3.new(-halfX - rimThickness * 0.5, rimHeight * 0.5, 0), Vector3.new(rimThickness, rimHeight, floorSize.Z) },
	}

	for index, rim in rims do
		makePart({
			Name = "Rim" .. index,
			Size = rim[2],
			Position = origin + rim[1],
			Color = HubConfig.COLORS.Rim,
			Parent = hub,
		})
	end

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for zoneId, zone in HubConfig.ZONES do
		local color = HubConfig.COLORS[zone.colorKey] or HubConfig.COLORS.Accent
		local position = HubConfig.worldPosition(zone.offset + Vector3.new(0, zone.size.Y * 0.5, 0))
		local zonePart = makePart({
			Name = zone.label,
			Size = zone.size,
			Position = position,
			Color = color,
			Transparency = 0.15,
			Parent = zonesFolder,
		})
		zonePart:SetAttribute("HubZone", zoneId)
		addBillboard(zonePart, zone.label)
		addProximityPrompt(zonePart, zone.prompt, zoneId)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.spawnPosition()
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = HubConfig.COLORS.Accent
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.35
	spawn.Parent = hub

	hubBuilt = true
	return hub
end

function HubWorldManager.isPlayerInHub(player)
	return playersInHub[player] == true
end

function HubWorldManager.getHubPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = HubWorldManager.getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = HubWorldManager.isPlayerInHub(player),
	}
end

function HubWorldManager.getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

function HubWorldManager.sendHubState(player)
	Remotes.HubState:FireClient(player, {
		inHub = HubWorldManager.isPlayerInHub(player),
		zones = HubConfig.ZONES,
	})
end

function HubWorldManager.refreshPlayerStats(player)
	Remotes.RefreshHubStats:FireClient(player, HubWorldManager.getHubPayload(player))
end

function HubWorldManager.spawnPlayerInHub(player)
	playersInHub[player] = true
	player:SetAttribute("InHub", true)

	local function placeInHub()
		teleportPlayer(player, HubConfig.spawnPosition())
		HubWorldManager.sendHubState(player)
		HubWorldManager.refreshPlayerStats(player)
	end

	if player.Character then
		placeInHub()
	else
		player.CharacterAdded:Once(placeInHub)
	end
end

function HubWorldManager.returnToHub(player)
	playersInHub[player] = true
	player:SetAttribute("InHub", true)
	teleportPlayer(player, HubConfig.spawnPosition())
	HubWorldManager.sendHubState(player)
	HubWorldManager.refreshPlayerStats(player)
	Remotes.LobbyReady:FireClient(player, HubWorldManager.getHubPayload(player))
end

function HubWorldManager.sendToArena(player)
	playersInHub[player] = false
	player:SetAttribute("InHub", false)
	teleportPlayer(player, HubConfig.ARENA_SPAWN)
	HubWorldManager.sendHubState(player)
end

function HubWorldManager.handleZonePrompt(player, zoneId)
	if not HubWorldManager.isPlayerInHub(player) then
		return
	end

	if zoneId == "ArenaGate" then
		HubWorldManager.sendToArena(player)
	elseif zoneId == "BeyShop" then
		Remotes.OpenBeySelect:FireClient(player)
	elseif zoneId == "HallOfFame" then
		HubWorldManager.refreshPlayerStats(player)
	end
end

function HubWorldManager.connectZonePrompts(hub)
	local zonesFolder = hub:FindFirstChild("Zones")
	if not zonesFolder then
		return
	end

	for _, zonePart in zonesFolder:GetChildren() do
		local prompt = zonePart:FindFirstChildOfClass("ProximityPrompt")
		if not prompt then
			continue
		end

		local zoneId = prompt:GetAttribute("HubZone")
		prompt.Triggered:Connect(function(player)
			HubWorldManager.handleZonePrompt(player, zoneId)
		end)
	end
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	HubWorldManager.spawnPlayerInHub(player)

	player.CharacterAdded:Connect(function()
		if HubWorldManager.isPlayerInHub(player) then
			task.defer(function()
				teleportPlayer(player, HubConfig.spawnPosition())
			end)
		end
	end)
end

function HubWorldManager.onPlayerRemoving(player)
	playersInHub[player] = nil
	PlayerDataManager.save(player)
end

return HubWorldManager
