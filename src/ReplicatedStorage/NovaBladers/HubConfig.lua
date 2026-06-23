local HubConfig = {
	SPAWN_POSITION = Vector3.new(0, 3.5, -25),
	SPAWN_SIZE = Vector3.new(6, 1, 6),

	FLOOR_SIZE = Vector3.new(120, 2, 120),
	FLOOR_CENTER = Vector3.new(0, 0, 0),

	WALL_HEIGHT = 14,
	WALL_THICKNESS = 2,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			hint = "Drücke E — Arena betreten",
			position = Vector3.new(0, 4, 35),
			size = Vector3.new(14, 10, 6),
			color = Color3.fromRGB(80, 140, 255),
		},
		BeyLab = {
			id = "BeyLab",
			label = "Bey-Labor",
			hint = "Drücke E — Bey wählen",
			position = Vector3.new(-32, 4, 0),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(255, 200, 60),
		},
		HallOfFame = {
			id = "HallOfFame",
			label = "Ruhmeshalle",
			hint = "Top-Spieler ansehen",
			position = Vector3.new(32, 4, 0),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(140, 80, 220),
		},
	},

	ARENA_SPAWN_NAMES = { "ArenaSpawn", "BowlSpawn", "Spawn" },
	ARENA_FOLDER_NAMES = { "Arena", "Bowl" },
}

return HubConfig
