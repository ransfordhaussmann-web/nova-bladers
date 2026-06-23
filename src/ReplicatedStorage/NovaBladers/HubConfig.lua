local HubConfig = {
	SPAWN = Vector3.new(0, 3.5, -25),
	FLOOR_SIZE = Vector3.new(80, 1, 70),
	FLOOR_CENTER = Vector3.new(0, 0, -5),
	WALL_HEIGHT = 12,

	ARENA_SPAWN_NAMES = { "Spawn", "ArenaSpawn", "PlayerSpawn" },
	ARENA_FALLBACK = Vector3.new(0, 5, 0),

	ZONES = {
		{
			id = "arena",
			name = "Arena-Tor",
			hint = "Drücke E — Arena betreten",
			position = Vector3.new(0, 1, 20),
			size = Vector3.new(14, 8, 10),
			color = Color3.fromRGB(255, 90, 70),
			action = "enterArena",
		},
		{
			id = "beylab",
			name = "Bey-Labor",
			hint = "Drücke E — Bey wählen",
			position = Vector3.new(-28, 1, -5),
			size = Vector3.new(12, 8, 12),
			color = Color3.fromRGB(80, 160, 255),
			action = "openBeySelect",
		},
		{
			id = "halloffame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler der Nova Bladers Arena",
			position = Vector3.new(28, 1, -5),
			size = Vector3.new(12, 8, 12),
			color = Color3.fromRGB(255, 200, 60),
			action = "viewLeaderboard",
		},
	},
}

return HubConfig
