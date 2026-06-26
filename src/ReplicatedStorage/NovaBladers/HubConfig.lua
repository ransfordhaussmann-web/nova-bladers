local HubConfig = {
	HUB_NAME = "NovaHub",
	HUB_ORIGIN = Vector3.new(0, 50, 120),

	-- Floor & bounds
	FLOOR_SIZE = Vector3.new(72, 1, 56),
	WALL_HEIGHT = 10,

	-- Spawn
	SPAWN_POSITION = Vector3.new(0, 4, 8),

	-- Interactive zones (offsets from HUB_ORIGIN)
	ARENA_GATE = {
		position = Vector3.new(0, 3, -22),
		size = Vector3.new(10, 8, 2),
		promptText = "Arena betreten",
		promptKey = Enum.KeyCode.E,
	},
	BEY_KIOSK = {
		position = Vector3.new(22, 3, -4),
		size = Vector3.new(5, 6, 5),
		promptText = "Bey wählen",
		promptKey = Enum.KeyCode.E,
	},
	LEADERBOARD = {
		position = Vector3.new(-22, 6, -8),
		size = Vector3.new(12, 8, 1),
		title = "Top Kämpfer",
	},
	STATS_BOARD = {
		position = Vector3.new(-22, 6, 6),
		size = Vector3.new(10, 6, 1),
		title = "Deine Stats",
	},

	-- Visual theme
	COLORS = {
		floor = Color3.fromRGB(28, 32, 48),
		floorAccent = Color3.fromRGB(45, 55, 85),
		wall = Color3.fromRGB(20, 24, 38),
		neon = Color3.fromRGB(80, 180, 255),
		neonAlt = Color3.fromRGB(140, 90, 255),
		gateGlow = Color3.fromRGB(100, 200, 255),
		kiosk = Color3.fromRGB(50, 45, 70),
	},

	MATERIALS = {
		floor = Enum.Material.Slate,
		wall = Enum.Material.Concrete,
		neon = Enum.Material.Neon,
		glass = Enum.Material.Glass,
	},

	LEADERBOARD_REFRESH = 30,
}

return HubConfig
