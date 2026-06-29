local HubConfig = {
	-- Hub center in Workspace; adjust to match your place layout.
	ORIGIN = Vector3.new(0, 0, 0),
	HUB_SPAWN = Vector3.new(0, 4, -24),
	ARENA_SPAWN_OFFSET = Vector3.new(0, 6, 140),

	FLOOR_SIZE = Vector3.new(128, 1, 96),

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			position = Vector3.new(0, 0, 38),
			size = Vector3.new(14, 12, 5),
			prompt = "Arena betreten",
			action = "enterArena",
		},
		BeyLab = {
			id = "BeyLab",
			label = "Bey-Labor",
			position = Vector3.new(-40, 0, 0),
			size = Vector3.new(16, 10, 16),
			prompt = "Bey wählen",
			action = "openBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			label = "Ruhmeshalle",
			position = Vector3.new(40, 0, 0),
			size = Vector3.new(16, 10, 16),
			prompt = "Statistiken ansehen",
			action = "showStats",
		},
	},

	COLORS = {
		floor = Color3.fromRGB(38, 42, 52),
		floorAccent = Color3.fromRGB(55, 60, 75),
		arenaGate = Color3.fromRGB(80, 140, 255),
		beyLab = Color3.fromRGB(255, 180, 60),
		hallOfFame = Color3.fromRGB(220, 180, 80),
		sign = Color3.fromRGB(240, 240, 250),
	},

	ZONE_CHECK_INTERVAL = 0.35,
	LEADERBOARD_TOP_COUNT = 5,
}

return HubConfig
