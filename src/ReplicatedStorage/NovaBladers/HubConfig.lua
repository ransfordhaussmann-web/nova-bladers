local HubConfig = {
	ORIGIN = Vector3.new(0, 0, 0),
	FLOOR_Y = 1,
	SPAWN_OFFSET = Vector3.new(0, 3, 0),
	FLOOR_RADIUS = 48,

	ZONES = {
		ArenaGate = {
			position = Vector3.new(0, 0, -34),
			radius = 7,
			prompt = "Arena betreten",
		},
		StatsKiosk = {
			position = Vector3.new(0, 0, 28),
			radius = 5,
			prompt = "Statistiken",
		},
		Leaderboard = {
			position = Vector3.new(30, 0, 0),
			radius = 6,
		},
		BeyShowcase = {
			position = Vector3.new(-30, 0, 0),
			radius = 12,
		},
	},

	COLORS = {
		floor = Color3.fromRGB(22, 26, 38),
		floorAccent = Color3.fromRGB(32, 38, 56),
		neon = Color3.fromRGB(100, 180, 255),
		neonDim = Color3.fromRGB(60, 100, 160),
		railing = Color3.fromRGB(45, 50, 70),
	},

	LEADERBOARD_REFRESH = 60,
}

return HubConfig
