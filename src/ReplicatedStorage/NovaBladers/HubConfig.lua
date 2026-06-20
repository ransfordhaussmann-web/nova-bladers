local HubConfig = {
	HUB_NAME = "NovaHub",
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	SPAWN_OFFSET = Vector3.new(0, 4, -40),
	WALL_HEIGHT = 16,

	ZONES = {
		{
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Betritt das Tor, um in die Arena zu kämpfen!",
			position = Vector3.new(0, 0, 35),
			size = Vector3.new(18, 12, 6),
			color = Color3.fromRGB(255, 90, 70),
		},
		{
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Wähle hier deinen Bey aus!",
			position = Vector3.new(-38, 0, 0),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(80, 160, 255),
		},
		{
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler der Nova Bladers Liga.",
			position = Vector3.new(38, 0, 0),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(255, 200, 60),
		},
	},

	ARENA_SPAWN_NAMES = { "Spawn", "ArenaSpawn" },
	ARENA_FOLDER = "Arena",
}

return HubConfig
