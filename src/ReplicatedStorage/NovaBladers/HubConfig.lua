local HubConfig = {
	SPAWN_POSITION = Vector3.new(0, 3.5, -25),
	HUB_FOLDER_NAME = "NovaHub",

	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 16,
	WALL_THICKNESS = 2,

	ZONE_RADIUS = 10,
	ZONE_CHECK_INTERVAL = 0.25,

	ARENA_SPAWN_PATH = { "Arena", "Bowl", "Spawn" },
	ARENA_SPAWN_FALLBACK = Vector3.new(0, 5, 0),

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Betrete die Spin-Arena",
			actionLabel = "Arena betreten [E]",
			position = Vector3.new(0, 2, 38),
			size = Vector3.new(20, 10, 14),
			color = Color3.fromRGB(80, 140, 255),
			action = "EnterArena",
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Wähle deinen Nova Bey",
			actionLabel = "Bey auswählen [E]",
			position = Vector3.new(-38, 2, 0),
			size = Vector3.new(16, 10, 16),
			color = Color3.fromRGB(255, 200, 60),
			action = "OpenBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Globale Top-Spieler",
			actionLabel = "Stats anzeigen [E]",
			position = Vector3.new(38, 2, 0),
			size = Vector3.new(16, 10, 16),
			color = Color3.fromRGB(140, 80, 220),
			action = "ShowStats",
		},
	},
}

return HubConfig
