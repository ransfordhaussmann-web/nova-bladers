local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local HubConfig = require(ReplicatedStorage:WaitForChild("NovaBladers"):WaitForChild("HubConfig"))

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.CastShadow = props.CastShadow ~= false
	part.Name = props.Name or "HubPart"
	part.Size = props.Size or Vector3.new(4, 4, 4)
	part.CFrame = props.CFrame or CFrame.new(props.Position or HubConfig.ORIGIN)
	part.Color = props.Color or HubConfig.COLORS.Floor
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Transparency = props.Transparency or 0
	part.Parent = props.Parent
	return part
end

local function addNeonStrip(parent, position, size, color)
	local strip = makePart({
		Name = "NeonStrip",
		Parent = parent,
		Position = position,
		Size = size,
		Color = color or HubConfig.COLORS.Neon,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CastShadow = false,
	})
	strip.Transparency = 0.15
	return strip
end

local function addBillboardAnchor(parent, name, position, title)
	local anchor = makePart({
		Name = name,
		Parent = parent,
		Position = position,
		Size = Vector3.new(1, 1, 1),
		Transparency = 1,
		CanCollide = false,
		CastShadow = false,
	})
	anchor:SetAttribute("HubBillboardTitle", title)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HubBillboard"
	billboard.AlwaysOnTop = false
	billboard.Size = UDim2.fromOffset(280, 160)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.MaxDistance = 80
	billboard.Parent = anchor

	local frame = Instance.new("Frame")
	frame.Name = "Frame"
	frame.BackgroundColor3 = Color3.fromRGB(18, 22, 34)
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = HubConfig.COLORS.Neon
	stroke.Thickness = 1.5
	stroke.Transparency = 0.35
	stroke.Parent = frame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Text = title
	titleLabel.TextColor3 = HubConfig.COLORS.Neon
	titleLabel.TextSize = 18
	titleLabel.Size = UDim2.new(1, -16, 0, 28)
	titleLabel.Position = UDim2.fromOffset(8, 6)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = frame

	local bodyLabel = Instance.new("TextLabel")
	bodyLabel.Name = "BodyLabel"
	bodyLabel.BackgroundTransparency = 1
	bodyLabel.Font = Enum.Font.Gotham
	bodyLabel.Text = "..."
	bodyLabel.TextColor3 = Color3.fromRGB(230, 235, 245)
	bodyLabel.TextSize = 15
	bodyLabel.TextWrapped = true
	bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
	bodyLabel.Size = UDim2.new(1, -16, 1, -40)
	bodyLabel.Position = UDim2.fromOffset(8, 34)
	bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
	bodyLabel.Parent = frame

	return anchor
end

function HubWorldBuilder.applyLighting()
	Lighting.ClockTime = 20.5
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(55, 60, 85)
	Lighting.OutdoorAmbient = Color3.fromRGB(40, 45, 65)
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.6
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaBladersHub")
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaBladersHub"
	hub.Parent = workspace

	local origin = HubConfig.ORIGIN

	makePart({
		Name = "HubFloor",
		Parent = hub,
		Position = origin + Vector3.new(0, -1, 0),
		Size = HubConfig.FLOOR_SIZE,
		Color = HubConfig.COLORS.Floor,
		Material = Enum.Material.Slate,
	})

	makePart({
		Name = "HubFloorAccent",
		Parent = hub,
		Position = origin + Vector3.new(0, -0.45, 0),
		Size = Vector3.new(HubConfig.FLOOR_SIZE.X - 6, 0.4, HubConfig.FLOOR_SIZE.Z - 6),
		Color = HubConfig.COLORS.FloorAccent,
		Material = Enum.Material.Metal,
	})

	local spawnPad = makePart({
		Name = "HubSpawn",
		Parent = hub,
		Position = HubConfig.SPAWN + Vector3.new(0, -0.2, 0),
		Size = Vector3.new(14, 0.6, 14),
		Color = HubConfig.COLORS.Spawn,
		Material = Enum.Material.Neon,
	})
	spawnPad.Transparency = 0.35

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "HubSpawnLocation"
	spawnLocation.Anchored = true
	spawnLocation.CanCollide = false
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0
	spawnLocation.Size = Vector3.new(12, 1, 12)
	spawnLocation.CFrame = CFrame.new(HubConfig.SPAWN)
	spawnLocation.Color = HubConfig.COLORS.Spawn
	spawnLocation.Material = Enum.Material.Neon
	spawnLocation.Transparency = 0.7
	spawnLocation.Parent = hub

	addNeonStrip(hub, HubConfig.SPAWN + Vector3.new(0, 0.2, 0), Vector3.new(14, 0.15, 0.4), HubConfig.COLORS.Spawn)
	addNeonStrip(hub, HubConfig.SPAWN + Vector3.new(0, 0.2, 0), Vector3.new(0.4, 0.15, 14), HubConfig.COLORS.Spawn)

	local gateBase = makePart({
		Name = "ArenaGateBase",
		Parent = hub,
		Position = HubConfig.ARENA_GATE + Vector3.new(0, -0.5, 0),
		Size = Vector3.new(16, 1, 8),
		Color = HubConfig.COLORS.FloorAccent,
		Material = Enum.Material.Metal,
	})

	local leftPillar = makePart({
		Name = "ArenaGateLeft",
		Parent = hub,
		Position = HubConfig.ARENA_GATE + Vector3.new(-6, 4, 0),
		Size = Vector3.new(2, 10, 2),
		Color = HubConfig.COLORS.Pillar,
	})
	local rightPillar = makePart({
		Name = "ArenaGateRight",
		Parent = hub,
		Position = HubConfig.ARENA_GATE + Vector3.new(6, 4, 0),
		Size = Vector3.new(2, 10, 2),
		Color = HubConfig.COLORS.Pillar,
	})
	local gateTop = makePart({
		Name = "ArenaGateTop",
		Parent = hub,
		Position = HubConfig.ARENA_GATE + Vector3.new(0, 9, 0),
		Size = Vector3.new(14, 1.5, 2),
		Color = HubConfig.COLORS.Portal,
		Material = Enum.Material.Neon,
	})
	gateTop.Transparency = 0.2

	local portalCore = makePart({
		Name = "ArenaGate",
		Parent = hub,
		Position = HubConfig.ARENA_GATE + Vector3.new(0, 3, 0),
		Size = Vector3.new(8, 8, 1),
		Color = HubConfig.COLORS.Portal,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CastShadow = false,
	})
	portalCore.Transparency = 0.55
	portalCore:SetAttribute("HubZone", "ArenaGate")

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EnterArenaPrompt"
	prompt.ActionText = "Arena betreten"
	prompt.ObjectText = "Nova Arena"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = HubConfig.INTERACT_RANGE
	prompt.RequiresLineOfSight = false
	prompt.Parent = portalCore

	addBillboardAnchor(hub, "HubStatsBoard", HubConfig.STATS_BOARD + Vector3.new(0, 2, 0), "Deine Stats")
	addBillboardAnchor(hub, "HubLeaderboard", HubConfig.LEADERBOARD + Vector3.new(0, 2, 0), "Top Spieler")

	for index, offset in ipairs({
		Vector3.new(-20, 0, -8),
		Vector3.new(20, 0, -8),
		Vector3.new(-20, 0, 8),
		Vector3.new(20, 0, 8),
	}) do
		makePart({
			Name = "HubPillar" .. index,
			Parent = hub,
			Position = origin + offset + Vector3.new(0, 3, 0),
			Size = Vector3.new(2.5, 6, 2.5),
			Color = HubConfig.COLORS.Pillar,
		})
	end

	local path = makePart({
		Name = "HubPath",
		Parent = hub,
		Position = origin + Vector3.new(0, -0.35, -15),
		Size = Vector3.new(8, 0.3, 28),
		Color = HubConfig.COLORS.FloorAccent,
		Material = Enum.Material.Concrete,
	})

	addNeonStrip(hub, origin + Vector3.new(-HubConfig.FLOOR_SIZE.X / 2 + 0.2, 1.5, 0), Vector3.new(0.3, 3, HubConfig.FLOOR_SIZE.Z - 4))
	addNeonStrip(hub, origin + Vector3.new(HubConfig.FLOOR_SIZE.X / 2 - 0.2, 1.5, 0), Vector3.new(0.3, 3, HubConfig.FLOOR_SIZE.Z - 4))
	addNeonStrip(hub, origin + Vector3.new(0, 1.5, -HubConfig.FLOOR_SIZE.Z / 2 + 0.2), Vector3.new(HubConfig.FLOOR_SIZE.X - 4, 3, 0.3))
	addNeonStrip(hub, origin + Vector3.new(0, 1.5, HubConfig.FLOOR_SIZE.Z / 2 - 0.2), Vector3.new(HubConfig.FLOOR_SIZE.X - 4, 3, 0.3))

	local showcase = makePart({
		Name = "BeyShowcasePad",
		Parent = hub,
		Position = HubConfig.BEY_SHOWCASE + Vector3.new(0, -0.3, 0),
		Size = Vector3.new(18, 0.5, 10),
		Color = HubConfig.COLORS.FloorAccent,
		Material = Enum.Material.Glass,
	})
	showcase.Transparency = 0.25

	addBillboardAnchor(hub, "HubWelcome", origin + Vector3.new(0, 6, -24), "Nova Bladers Hub")
		:FindFirstChild("HubBillboard").Frame.BodyLabel.Text = "Laufe zum Portal oder nutze Start im Menü."

	HubWorldBuilder.applyLighting()

	return hub
end

function HubWorldBuilder.getArenaSpawnCFrame()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local spawn = arena:FindFirstChild("Spawn", true)
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(HubConfig.ARENA_FALLBACK)
end

return HubWorldBuilder
