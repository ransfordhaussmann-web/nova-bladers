local HubConfig = {
	SPAWN = Vector3.new(0, 3, 0),
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 16,

	ZONES = {
		{
			id = "ArenaGate",
			name = "Arena-Tor",
			position = Vector3.new(0, 2, -42),
			size = Vector3.new(18, 10, 6),
			color = Color3.fromRGB(255, 90, 70),
			action = "enterArena",
			prompt = "Arena betreten",
		},
		{
			id = "BeyLab",
			name = "Bey-Labor",
			position = Vector3.new(-38, 2, 10),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(80, 160, 255),
			action = "openBeySelect",
			prompt = "Bey wählen",
		},
		{
			id = "HallOfFame",
			name = "Ruhmeshalle",
			position = Vector3.new(38, 2, 10),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(255, 200, 60),
			action = "showHall",
			prompt = "Statistiken anzeigen (E)",
		},
	},

	ARENA_SPAWN_NAMES = { "ArenaSpawn", "Arena.ArenaSpawn" },
	ARENA_FALLBACK = Vector3.new(0, 5, 0),
}

return HubConfig
