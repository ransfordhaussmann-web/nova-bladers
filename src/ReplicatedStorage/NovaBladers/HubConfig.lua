local HubConfig = {
	ROOT_NAME = "NovaBladersHub",

	SPAWN = Vector3.new(0, 4, 0),
	FLOOR_SIZE = Vector2.new(128, 128),
	FLOOR_Y = 0,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			position = Vector3.new(0, 0, -48),
			radius = 10,
			label = "Arena-Tor",
			prompt = "E — Arena betreten",
		},
		BeyTerminal = {
			id = "BeyTerminal",
			position = Vector3.new(-40, 0, 12),
			radius = 8,
			label = "Bey-Terminal",
			prompt = "E — Bey wählen",
		},
		StatsBoard = {
			id = "StatsBoard",
			position = Vector3.new(40, 0, 12),
			radius = 8,
			label = "Statistik-Pylon",
			prompt = "E — Stats anzeigen",
		},
	},

	COLORS = {
		Floor = Color3.fromRGB(28, 32, 48),
		FloorAccent = Color3.fromRGB(45, 55, 80),
		SpawnPad = Color3.fromRGB(70, 130, 255),
		Path = Color3.fromRGB(55, 65, 95),
		ArenaGate = Color3.fromRGB(255, 90, 70),
		BeyTerminal = Color3.fromRGB(80, 200, 120),
		StatsBoard = Color3.fromRGB(255, 200, 60),
		Neon = Color3.fromRGB(120, 180, 255),
	},

	STRUCTURES = {
		ArenaArchHeight = 14,
		ArenaArchWidth = 18,
		TerminalHeight = 10,
		StatsPylonHeight = 12,
	},

	PROXIMITY_CHECK_INTERVAL = 0.15,
}

return HubConfig
