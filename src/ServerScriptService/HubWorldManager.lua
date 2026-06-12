local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local HUB_FOLDER_NAME = "NovaHub"
local ARENA_SPAWN_NAME = "ArenaSpawn"
local HUB_SPAWN_OFFSET = Vector3.new(0, 4, 0)

local ZONE_DEFS = {
	Arena = {
		id = "Arena",
		label = "Arena",
		hint = "Betrete die Arena und starte einen Kampf.",
		color = Color3.fromRGB(255, 90, 70),
		position = Vector3.new(0, 1, -42),
		size = Vector3.new(22, 1, 14),
	},
	BeySelect = {
		id = "BeySelect",
		label = "Bey-Auswahl",
		hint = "Wähle deinen Nova Blader.",
		color = Color3.fromRGB(70, 140, 255),
		position = Vector3.new(42, 1, 0),
		size = Vector3.new(14, 1, 22),
	},
	Leaderboard = {
		id = "Leaderboard",
		label = "Rangliste",
		hint = "Sieh die Top-Spieler der Lobby.",
		color = Color3.fromRGB(255, 200, 60),
		position = Vector3.new(-42, 1, 0),
		size = Vector3.new(14, 1, 22),
	},
}

local HubWorldManager = {}
local hubFolder = nil
local hubSpawnCFrame = CFrame.new(HUB_SPAWN_OFFSET)
local arenaSpawnCFrame = nil
local playersInArena = {}
local zoneDebounce = {}

local function getRemotes()
	return RemotesSetup
end

local function createPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Color = props.Color or Color3.fromRGB(45, 48, 58)
	part.Size = props.Size or Vector3.new(4, 1, 4)
	part.CFrame = props.CFrame or CFrame.new(props.Position or Vector3.zero)
	part.Name = props.Name or "Part"
	part.Transparency = props.Transparency or 0
	part.Parent = props.Parent
	return part
end

local function createBillboard(parent, text, color)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 48)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.TextSize = 20
	label.Text = text
	label.Parent = billboard
end

local function createZone(parent, def)
	local pad = createPart({
		Name = def.id .. "Pad",
		Parent = parent,
		Position = def.position,
		Size = def.size,
		Color = def.color,
		Material = Enum.Material.Neon,
		Transparency = 0.25,
	})
	pad:SetAttribute("HubZoneId", def.id)

	local trigger = createPart({
		Name = def.id .. "Trigger",
		Parent = pad,
		Position = def.position + Vector3.new(0, 4, 0),
		Size = Vector3.new(def.size.X, 8, def.size.Z),
		Transparency = 1,
		CanCollide = false,
	})
	trigger:SetAttribute("HubZoneId", def.id)
	trigger.Touched:Connect(function(hit)
		onZoneTouched(def.id, hit)
	end)

	createBillboard(pad, def.label, def.color)

	local archHeight = 10
	local archThickness = 1.2
	if def.id == "Arena" then
		createPart({
			Name = "ArenaArchLeft",
			Parent = pad,
			Position = def.position + Vector3.new(-def.size.X * 0.35, archHeight * 0.5, 0),
			Size = Vector3.new(archThickness, archHeight, archThickness),
			Color = def.color,
			Material = Enum.Material.Metal,
		})
		createPart({
			Name = "ArenaArchRight",
			Parent = pad,
			Position = def.position + Vector3.new(def.size.X * 0.35, archHeight * 0.5, 0),
			Size = Vector3.new(archThickness, archHeight, archThickness),
			Color = def.color,
			Material = Enum.Material.Metal,
		})
		createPart({
			Name = "ArenaArchTop",
			Parent = pad,
			Position = def.position + Vector3.new(0, archHeight, 0),
			Size = Vector3.new(def.size.X * 0.75, archThickness, archThickness),
			Color = def.color,
			Material = Enum.Material.Metal,
		})
	end

	return pad, trigger
end

local function onZoneTouched(zoneId, hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return
	end
	local player = Players:GetPlayerFromCharacter(character)
	if not player or playersInArena[player] then
		return
	end

	local now = os.clock()
	local last = zoneDebounce[player]
	if last and (now - last) < 1.2 then
		return
	end
	zoneDebounce[player] = now

	local def = ZONE_DEFS[zoneId]
	if not def then
		return
	end

	getRemotes().HubZoneTouched:FireClient(player, {
		zoneId = def.id,
		label = def.label,
		hint = def.hint,
	})
end

local function buildFloor(parent)
	createPart({
		Name = "HubFloor",
		Parent = parent,
		Position = Vector3.new(0, 0, 0),
		Size = Vector3.new(120, 2, 120),
		Color = Color3.fromRGB(32, 34, 42),
		Material = Enum.Material.Slate,
	})

	createPart({
		Name = "HubCenter",
		Parent = parent,
		Position = Vector3.new(0, 1.05, 0),
		Size = Vector3.new(28, 0.2, 28),
		Color = Color3.fromRGB(55, 60, 75),
		Material = Enum.Material.Marble,
	})

	for i = 1, 4 do
		local angle = math.rad(45 + (i - 1) * 90)
		local radius = 34
		createPart({
			Name = "HubPillar" .. i,
			Parent = parent,
			Position = Vector3.new(math.cos(angle) * radius, 6, math.sin(angle) * radius),
			Size = Vector3.new(3, 12, 3),
			Color = Color3.fromRGB(70, 75, 95),
			Material = Enum.Material.Concrete,
		})
	end

	createPart({
		Name = "HubSpawn",
		Parent = parent,
		Position = HUB_SPAWN_OFFSET,
		Size = Vector3.new(6, 0.4, 6),
		Color = Color3.fromRGB(120, 200, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.35,
	})
	hubSpawnCFrame = CFrame.new(HUB_SPAWN_OFFSET + Vector3.new(0, 3, 0))
end

local function buildPathways(parent)
	local pathColor = Color3.fromRGB(48, 52, 64)
	for _, def in ZONE_DEFS do
		local direction = def.position.Unit
		local mid = direction * (def.position.Magnitude * 0.5)
		createPart({
			Name = def.id .. "Path",
			Parent = parent,
			Position = Vector3.new(mid.X, 1.02, mid.Z),
			Size = Vector3.new(
				math.max(6, math.abs(def.position.X) > 0 and 8 or def.size.X * 0.5),
				0.15,
				math.max(6, math.abs(def.position.Z) > 0 and 8 or def.size.Z * 0.5)
			),
			Color = pathColor,
			Material = Enum.Material.Cobblestone,
		})
	end
end

function HubWorldManager.build()
	local existing = Workspace:FindFirstChild(HUB_FOLDER_NAME)
	if existing then
		existing:Destroy()
	end

	hubFolder = Instance.new("Folder")
	hubFolder.Name = HUB_FOLDER_NAME
	hubFolder.Parent = Workspace

	buildFloor(hubFolder)
	buildPathways(hubFolder)

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hubFolder

	for _, def in ZONE_DEFS do
		createZone(zonesFolder, def)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawnLocation"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = hubSpawnCFrame
	spawn.Parent = hubFolder

	local arenaSpawn = Workspace:FindFirstChild(ARENA_SPAWN_NAME)
	if arenaSpawn and arenaSpawn:IsA("BasePart") then
		arenaSpawnCFrame = arenaSpawn.CFrame + Vector3.new(0, 3, 0)
	else
		arenaSpawnCFrame = CFrame.new(0, 6, 80)
	end

	return hubFolder
end

function HubWorldManager.getHubSpawnCFrame()
	return hubSpawnCFrame
end

function HubWorldManager.getArenaSpawnCFrame()
	return arenaSpawnCFrame or CFrame.new(0, 6, 80)
end

function HubWorldManager.isInArena(player)
	return playersInArena[player] == true
end

function HubWorldManager.teleportToHub(player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	playersInArena[player] = false
	player:SetAttribute("InArena", false)
	root.CFrame = hubSpawnCFrame
end

function HubWorldManager.sendToArena(player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	playersInArena[player] = true
	player:SetAttribute("InArena", true)
	root.CFrame = HubWorldManager.getArenaSpawnCFrame()

	local entryEvent = ServerScriptService:FindFirstChild("ArenaEntryRequested")
	if entryEvent and entryEvent:IsA("BindableEvent") then
		entryEvent:Fire(player)
	end
end

HubWorldManager.returnToHub = HubWorldManager.teleportToHub

function HubWorldManager.onPlayerRemoving(player)
	playersInArena[player] = nil
	zoneDebounce[player] = nil
end

return HubWorldManager
