local HubConfig = {
	HUB_FOLDER = "NovaHub",
	SPAWN_NAME = "HubSpawn",

	FLOOR_SIZE = Vector3.new(80, 1, 80),
	FLOOR_POSITION = Vector3.new(0, 0.5, 0),
	WALL_HEIGHT = 12,
	WALL_THICKNESS = 2,

	ARENA_SPAWN_PATH = { "Arena", "ArenaSpawn" },
	ARENA_FALLBACK = Vector3.new(0, 5, 50),

	ZONES = {
		{
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "E — Arena betreten",
			position = Vector3.new(0, 1, -28),
			size = Vector3.new(14, 8, 6),
			color = Color3.fromRGB(255, 90, 70),
			action = "enterArena",
		},
		{
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "E — Bey wählen",
			position = Vector3.new(-26, 1, 10),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(80, 160, 255),
			action = "openBeySelect",
		},
		{
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "E — Stats anzeigen",
			position = Vector3.new(26, 1, 10),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(255, 200, 60),
			action = "showHall",
		},
	},

	INTERACT_RANGE = 10,
	PROMPT_KEY = Enum.KeyCode.E,
}

return HubConfig
