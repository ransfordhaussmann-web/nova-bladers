local HubConfig = {
	HUB_NAME = "NovaHub",
	HUB_ORIGIN = Vector3.new(0, 0.5, -120),
	FLOOR_SIZE = Vector3.new(80, 1, 80),
	WALL_HEIGHT = 12,
	SPAWN_OFFSET = Vector3.new(0, 3, 0),
	INTERACT_RANGE = 12,

	ARENA_SPAWN_PATHS = {
		"Workspace.Arena.ArenaSpawn",
		"Workspace.ArenaSpawn",
	},

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Drücke E um zu kämpfen",
			position = Vector3.new(0, 0, -28),
			size = Vector3.new(14, 1, 6),
			color = Color3.fromRGB(255, 95, 70),
			action = "enterArena",
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Drücke E für Bey-Auswahl",
			position = Vector3.new(-24, 0, 8),
			size = Vector3.new(10, 1, 10),
			color = Color3.fromRGB(70, 150, 255),
			action = "openBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Drücke E für Statistiken",
			position = Vector3.new(24, 0, 8),
			size = Vector3.new(10, 1, 10),
			color = Color3.fromRGB(255, 200, 60),
			action = "showHall",
		},
	},
}

return HubConfig
