local HubConfig = {
	ORIGIN = Vector3.new(0, 8, 0),
	FLOOR_SIZE = Vector3.new(100, 1, 100),
	WALL_HEIGHT = 14,

	SPAWN_OFFSET = Vector3.new(0, 4, -32),

	INTERACT_RANGE = 14,
	PROMPT_KEY = Enum.KeyCode.E,

	ARENA_SPAWN_NAMES = { "ArenaSpawn", "Arena.ArenaSpawn" },

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			hint = "Drücke E um zu kämpfen",
			position = Vector3.new(0, 0, 38),
			size = Vector3.new(22, 12, 10),
			color = Color3.fromRGB(255, 90, 70),
			action = "enterArena",
		},
		BeyLab = {
			id = "BeyLab",
			label = "Bey-Labor",
			hint = "Drücke E für Bey-Auswahl",
			position = Vector3.new(-38, 0, 0),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(80, 160, 255),
			action = "openBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			label = "Ruhmeshalle",
			hint = "Drücke E für Stats & Rangliste",
			position = Vector3.new(38, 0, 0),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(255, 200, 60),
			action = "showHall",
		},
	},

	COLORS = {
		Floor = Color3.fromRGB(35, 38, 48),
		Wall = Color3.fromRGB(50, 55, 68),
		Accent = Color3.fromRGB(120, 200, 255),
		SpawnPad = Color3.fromRGB(90, 100, 120),
	},
}

return HubConfig
