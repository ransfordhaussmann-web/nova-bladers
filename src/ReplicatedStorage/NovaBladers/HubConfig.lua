local HubConfig = {
	FLOOR_SIZE = Vector3.new(96, 1, 96),
	WALL_HEIGHT = 12,
	SPAWN_POSITION = Vector3.new(0, 3, 28),

	ZONES = {
		Arena = {
			id = "Arena",
			name = "Arena-Tor",
			position = Vector3.new(0, 0, -35),
			size = Vector3.new(16, 8, 12),
			color = Color3.fromRGB(255, 100, 80),
			hint = "Drücke E um die Arena zu betreten",
			action = "EnterArena",
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			position = Vector3.new(-35, 0, 0),
			size = Vector3.new(12, 8, 16),
			color = Color3.fromRGB(80, 140, 255),
			hint = "Drücke E um deinen Bey zu wählen",
			action = "OpenBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			position = Vector3.new(35, 0, 0),
			size = Vector3.new(12, 8, 16),
			color = Color3.fromRGB(255, 200, 60),
			hint = "Top-Spieler der Nova Bladers",
			action = nil,
		},
	},

	ARENA_FOLDER = "Arena",
	ARENA_SPAWN_NAMES = { "Spawn", "ArenaSpawn" },
	HUB_FOLDER = "NovaHub",
}

return HubConfig
