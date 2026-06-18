local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	SPAWN_POSITION = Vector3.new(0, 4, 8),
	FLOOR_SIZE = Vector3.new(72, 1, 72),
	WALL_HEIGHT = 14,
	WALL_THICKNESS = 2,

	CEILING_LIGHT_BRIGHTNESS = 1.2,
	AMBIENT = Color3.fromRGB(45, 50, 70),
	OUTDOOR_AMBIENT = Color3.fromRGB(70, 75, 95),

	ZONES = {
		{
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Betrete die Spin-Arena",
			position = Vector3.new(0, 1, -28),
			size = Vector3.new(16, 0.5, 12),
			color = Color3.fromRGB(255, 95, 75),
			promptAction = "EnterArena",
			promptKey = Enum.KeyCode.E,
		},
		{
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Wähle deinen Nova Bey",
			position = Vector3.new(-24, 1, 0),
			size = Vector3.new(12, 0.5, 12),
			color = Color3.fromRGB(80, 150, 255),
			promptAction = "OpenBeySelect",
			promptKey = Enum.KeyCode.E,
		},
		{
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Stats & Top-Spieler",
			position = Vector3.new(24, 1, 0),
			size = Vector3.new(12, 0.5, 12),
			color = Color3.fromRGB(255, 200, 70),
			promptAction = "ShowHallOfFame",
			promptKey = Enum.KeyCode.E,
		},
	},

	ARENA_SPAWN_PATHS = {
		{ "Arena", "ArenaSpawn" },
		{ "ArenaSpawn" },
	},

	PROXIMITY_MAX_DISTANCE = 10,
}

return HubConfig
