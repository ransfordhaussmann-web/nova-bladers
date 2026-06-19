local HubConfig = {
	HUB_NAME = "NovaHub",
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 12,
	WALL_THICKNESS = 2,
	SPAWN_OFFSET = Vector3.new(0, 3, 0),

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			hint = "Betreten zum Kämpfen",
			action = "EnterArena",
			position = Vector3.new(0, 0, -45),
			size = Vector3.new(22, 10, 14),
			color = Color3.fromRGB(255, 90, 70),
		},
		BeyLab = {
			id = "BeyLab",
			label = "Bey-Labor",
			hint = "Bey auswählen",
			action = "OpenBeySelect",
			position = Vector3.new(45, 0, 0),
			size = Vector3.new(14, 10, 22),
			color = Color3.fromRGB(70, 160, 255),
		},
		HallOfFame = {
			id = "HallOfFame",
			label = "Ruhmeshalle",
			hint = "Stats & Leaderboard",
			action = "ShowHallOfFame",
			position = Vector3.new(-45, 0, 0),
			size = Vector3.new(14, 10, 22),
			color = Color3.fromRGB(255, 200, 60),
		},
	},

	ARENA_SPAWN_NAMES = { "Arena.ArenaSpawn", "ArenaSpawn" },
}

return HubConfig
