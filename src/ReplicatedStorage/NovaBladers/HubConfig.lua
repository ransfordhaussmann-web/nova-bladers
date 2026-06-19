local HubConfig = {
	ROOT_NAME = "NovaBladersHub",
	CENTER = Vector3.new(0, 0, 120),
	SPAWN_OFFSET = Vector3.new(0, 4, 0),
	FLOOR_RADIUS = 52,
	FLOOR_THICKNESS = 2,

	ZONES = {
		ArenaGate = {
			offset = Vector3.new(0, 0, -42),
			label = "Arena-Tor",
			hint = "Drücke E — Match starten",
		},
		Leaderboard = {
			offset = Vector3.new(42, 0, 0),
			label = "Rangliste",
			hint = "Top 5 Spieler",
		},
		StatsTerminal = {
			offset = Vector3.new(-42, 0, 0),
			label = "Deine Stats",
			hint = "Siege & Niederlagen",
		},
		BeyShowcase = {
			offset = Vector3.new(0, 0, 38),
			label = "Bey-Schaukasten",
			hint = "Wähle deinen Kämpfer in der Arena",
		},
	},

	ARENA_GATE = {
		size = Vector3.new(14, 12, 3),
		promptDistance = 10,
	},

	BOARD = {
		size = Vector3.new(10, 8, 1),
	},

	PEDESTAL = {
		radius = 5,
		spacing = 14,
	},

	COLORS = {
		floor = Color3.fromRGB(28, 32, 48),
		floorAccent = Color3.fromRGB(45, 55, 85),
		wall = Color3.fromRGB(18, 22, 36),
		neon = Color3.fromRGB(80, 160, 255),
		neonWarm = Color3.fromRGB(255, 180, 60),
		gate = Color3.fromRGB(100, 200, 255),
	},
}

return HubConfig
