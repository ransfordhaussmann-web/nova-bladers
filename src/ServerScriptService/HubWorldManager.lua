local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local HubWorldManager = {}

local playerState = {}
local zoneCooldowns = {}
local hubModel = nil

local function getRemotes()
	local folder = ReplicatedStorage:WaitForChild("NovaBladers"):WaitForChild("Remotes")
	return {
		LobbyReady = folder:WaitForChild("LobbyReady"),
		EnterArena = folder:WaitForChild("EnterArena"),
		OpenBeySelect = folder:FindFirstChild("OpenBeySelect"),
		HubZoneHint = folder:FindFirstChild("HubZoneHint"),
	}
end

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Size = props.Size
	part.Position = props.Position
	part.Color = props.Color or Color3.fromRGB(45, 48, 58)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Name = props.Name or "Part"
	part.Parent = props.Parent
	if props.Transparency then
		part.Transparency = props.Transparency
	end
	return part
end

local function addZoneLabel(part, zone)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = part

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 0.35
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	frame.Parent = gui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.45, 0)
	title.Position = UDim2.fromScale(0, 0.08)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextScaled = true
	title.Text = zone.label
	title.Parent = frame

	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.new(1, 0, 0.3, 0)
	hint.Position = UDim2.fromScale(0, 0.55)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.TextColor3 = Color3.fromRGB(200, 205, 220)
	hint.TextScaled = true
	hint.Text = zone.hint
	hint.Parent = frame
end

local function addZoneBeacon(parent, zone)
	local pillar = makePart({
		Name = zone.id .. "Beacon",
		Parent = parent,
		Size = Vector3.new(1.2, 6, 1.2),
		Position = HubConfig.HUB_ORIGIN + zone.position + Vector3.new(0, 4, 0),
		Color = zone.color,
		Material = Enum.Material.Neon,
	})
	pillar.CanCollide = false

	local light = Instance.new("PointLight")
	light.Color = zone.lightColor
	light.Brightness = 1.2
	light.Range = 18
	light.Parent = pillar
end

function HubWorldManager.buildHubWorld()
	if hubModel and hubModel.Parent then
		return hubModel
	end

	local origin = HubConfig.HUB_ORIGIN
	hubModel = Instance.new("Model")
	hubModel.Name = "NovaHub"
	hubModel.Parent = workspace

	local floor = makePart({
		Name = "Floor",
		Parent = hubModel,
		Size = HubConfig.FLOOR_SIZE,
		Position = origin,
		Color = Color3.fromRGB(35, 38, 48),
		Material = Enum.Material.Slate,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = origin + HubConfig.SPAWN_OFFSET
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hubModel

	-- Decorative rim
	for _, offset in { Vector3.new(0, 0, -HubConfig.FLOOR_SIZE.Z / 2), Vector3.new(0, 0, HubConfig.FLOOR_SIZE.Z / 2) } do
		makePart({
			Name = "Rim",
			Parent = hubModel,
			Size = Vector3.new(HubConfig.FLOOR_SIZE.X, 0.6, 1.2),
			Position = origin + offset + Vector3.new(0, 0.8, 0),
			Color = Color3.fromRGB(80, 140, 255),
			Material = Enum.Material.Neon,
		})
	end

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hubModel

	for _, zone in HubConfig.ZONES do
		local pad = makePart({
			Name = zone.id .. "Pad",
			Parent = zonesFolder,
			Size = zone.size + Vector3.new(0, 0.4, 0),
			Position = origin + zone.position + Vector3.new(0, 0.7, 0),
			Color = zone.color,
			Material = Enum.Material.Neon,
		})
		pad:SetAttribute("ZoneId", zone.id)
		addZoneLabel(pad, zone)
		addZoneBeacon(hubModel, zone)
	end

	-- Center logo platform
	makePart({
		Name = "CenterPlatform",
		Parent = hubModel,
		Size = Vector3.new(14, 0.5, 14),
		Position = origin + Vector3.new(0, 0.5, 0),
		Color = Color3.fromRGB(55, 58, 72),
		Material = Enum.Material.Metal,
	})

	local sign = makePart({
		Name = "HubSign",
		Parent = hubModel,
		Size = Vector3.new(16, 4, 0.4),
		Position = origin + Vector3.new(0, 10, HubConfig.FLOOR_SIZE.Z / 2 - 2),
		Color = Color3.fromRGB(25, 28, 38),
		Material = Enum.Material.SmoothPlastic,
	})

	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.Parent = sign
	local signText = Instance.new("TextLabel")
	signText.Size = UDim2.fromScale(1, 1)
	signText.BackgroundTransparency = 1
	signText.Font = Enum.Font.GothamBlack
	signText.TextColor3 = Color3.fromRGB(120, 200, 255)
	signText.TextScaled = true
	signText.Text = "NOVA BLADERS"
	signText.Parent = signGui

	hubModel.PrimaryPart = floor
	return hubModel
end

function HubWorldManager.isInArena(player)
	return playerState[player] == "arena"
end

function HubWorldManager.isInHub(player)
	return playerState[player] == "hub" or playerState[player] == nil
end

local function teleportPlayer(player, position)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = CFrame.new(position)
end

function HubWorldManager.returnToHub(player, lobbyPayload)
	playerState[player] = "hub"

	local spawnPos = HubConfig.HUB_ORIGIN + HubConfig.SPAWN_OFFSET
	teleportPlayer(player, spawnPos)

	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 16
		humanoid.JumpPower = 50
	end

	if lobbyPayload then
		local remotes = getRemotes()
		remotes.LobbyReady:FireClient(player, lobbyPayload)
	end
end

function HubWorldManager.sendToArena(player)
	playerState[player] = "arena"
	teleportPlayer(player, HubConfig.ARENA_ENTRY)

	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
	end
end

local function canTriggerZone(player)
	local now = os.clock()
	local last = zoneCooldowns[player]
	if last and (now - last) < HubConfig.ZONE_TOUCH_COOLDOWN then
		return false
	end
	zoneCooldowns[player] = now
	return true
end

function HubWorldManager.setupZoneHandlers(onArenaEnter, onBeySelect, onLeaderboard)
	local remotes = getRemotes()
	local zonesFolder = hubModel and hubModel:FindFirstChild("Zones")
	if not zonesFolder then return end

	for _, pad in zonesFolder:GetChildren() do
		if not pad:IsA("BasePart") then
			continue
		end

		pad.Touched:Connect(function(hit)
			local character = hit.Parent
			if not character then return end
			local player = Players:GetPlayerFromCharacter(character)
			if not player or not HubWorldManager.isInHub(player) then return end
			if not canTriggerZone(player) then return end

			local zoneId = pad:GetAttribute("ZoneId")
			if zoneId == "Arena" then
				if onArenaEnter then
					onArenaEnter(player)
				end
			elseif zoneId == "BeySelect" then
				if onBeySelect then
					onBeySelect(player)
				elseif remotes.OpenBeySelect then
					remotes.OpenBeySelect:FireClient(player)
				end
			elseif zoneId == "Leaderboard" then
				if onLeaderboard then
					onLeaderboard(player)
				end
			end

			if remotes.HubZoneHint then
				remotes.HubZoneHint:FireClient(player, zoneId)
			end
		end)
	end
end

function HubWorldManager.clearPlayer(player)
	playerState[player] = nil
	zoneCooldowns[player] = nil
end

return HubWorldManager
