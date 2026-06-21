local HubConfig = {
	HUB_FOLDER = "NovaHub",
	ARENA_FOLDER = "Arena",

	HUB_SIZE = Vector3.new(120, 1, 120),
	HUB_CENTER = Vector3.new(0, 0.5, -80),
	SPAWN_OFFSET = Vector3.new(0, 3, 0),

	WALL_HEIGHT = 16,
	FLOOR_COLOR = Color3.fromRGB(35, 38, 52),
	WALL_COLOR = Color3.fromRGB(55, 60, 82),
	ACCENT_COLOR = Color3.fromRGB(90, 140, 255),

	ZONE_CHECK_INTERVAL = 0.25,
	LEADERBOARD_REFRESH = 30,
	LEADERBOARD_TOP = 5,

	ZONES = {
		{
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Drücke E, um die Arena zu betreten.",
			action = "enterArena",
			offset = Vector3.new(0, 0, 42),
			size = Vector3.new(28, 1, 18),
			color = Color3.fromRGB(255, 110, 90),
		},
		{
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Drücke E, um deinen Bey zu wählen.",
			action = "openBeySelect",
			offset = Vector3.new(-38, 0, -10),
			size = Vector3.new(22, 1, 22),
			color = Color3.fromRGB(80, 200, 140),
		},
		{
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler der Nova Liga.",
			action = "none",
			offset = Vector3.new(38, 0, -10),
			size = Vector3.new(22, 1, 22),
			color = Color3.fromRGB(255, 200, 80),
		},
	},

	ARENA_SPAWN_NAMES = { "Spawn", "ArenaSpawn" },
}

return HubConfig
