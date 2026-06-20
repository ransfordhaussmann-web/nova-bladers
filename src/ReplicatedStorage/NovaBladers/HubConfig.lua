local HubConfig = {
	ROOT_NAME = "NovaHub",

	SPAWN = Vector3.new(0, 4, 0),
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 14,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			hint = "Drücke E um die Arena zu betreten",
			position = Vector3.new(0, 2, -42),
			size = Vector3.new(18, 12, 4),
			color = Color3.fromRGB(255, 120, 60),
			action = "enterArena",
		},
		BeyLab = {
			id = "BeyLab",
			label = "Bey-Labor",
			hint = "Drücke E um deinen Bey zu wählen",
			position = Vector3.new(-38, 2, 10),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(80, 160, 255),
			action = "openBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			label = "Ruhmeshalle",
			hint = "Drücke E für Stats & Leaderboard",
			position = Vector3.new(38, 2, 10),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(255, 210, 80),
			action = "showHallPanel",
		},
	},

	ARENA_SPAWN_NAMES = { "ArenaSpawn", "Spawn" },
	ARENA_FOLDER = "Arena",
}

return HubConfig
