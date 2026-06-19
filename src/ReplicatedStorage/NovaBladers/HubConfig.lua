local HubConfig = {
	ORIGIN = Vector3.new(0, 0, -120),

	SPAWN = Vector3.new(0, 4, -128),
	ARENA_GATE = Vector3.new(0, 4, -98),
	LEADERBOARD = Vector3.new(-20, 4, -112),
	STATS_BOARD = Vector3.new(20, 4, -112),
	BEY_SHOWCASE = Vector3.new(0, 4, -142),

	FLOOR_SIZE = Vector3.new(64, 2, 56),
	GATE_RADIUS = 9,
	INTERACT_RANGE = 12,

	COLORS = {
		Floor = Color3.fromRGB(28, 32, 48),
		FloorAccent = Color3.fromRGB(45, 55, 85),
		Neon = Color3.fromRGB(90, 160, 255),
		Portal = Color3.fromRGB(120, 200, 255),
		Pillar = Color3.fromRGB(38, 42, 62),
		Spawn = Color3.fromRGB(80, 200, 140),
	},

	ARENA_FALLBACK = Vector3.new(0, 6, 0),
}

return HubConfig
