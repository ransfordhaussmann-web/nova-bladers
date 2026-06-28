local HubConfig = {
	SPAWN_POSITION = Vector3.new(0, 5, 0),
	FLOOR_SIZE = Vector3.new(72, 1, 72),
	WALL_HEIGHT = 10,
	ARENA_PORTAL = {
		position = Vector3.new(0, 6, -28),
		size = Vector3.new(14, 10, 3),
	},
	STATS_TERMINAL = {
		position = Vector3.new(-22, 4, 12),
		size = Vector3.new(4, 3, 4),
	},
	LEADERBOARD = {
		position = Vector3.new(22, 7, 12),
		size = Vector3.new(10, 8, 1),
	},
	BEY_SHOWCASE = {
		position = Vector3.new(0, 3, 18),
		radius = 8,
	},
	THEME = {
		FloorColor = Color3.fromRGB(32, 36, 48),
		AccentColor = Color3.fromRGB(80, 140, 255),
		WallColor = Color3.fromRGB(22, 25, 34),
		PortalColor = Color3.fromRGB(100, 180, 255),
		TrimColor = Color3.fromRGB(60, 70, 95),
	},
	ZONE_RADIUS = 7,
	PORTAL_PROMPT_DISTANCE = 10,
}

return HubConfig
