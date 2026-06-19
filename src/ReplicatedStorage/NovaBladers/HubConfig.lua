local HubConfig = {
	HUB_NAME = "NovaHub",
	SPAWN_OFFSET = Vector3.new(0, 3, 0),
	FLOOR_SIZE = Vector3.new(80, 1, 80),
	WALL_HEIGHT = 12,
	WALL_THICKNESS = 2,
	ZONE_TRIGGER_RADIUS = 8,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			desc = "Betritt die Spin-Arena",
			position = Vector3.new(-25, 0, -20),
			size = Vector3.new(12, 8, 4),
			color = Color3.fromRGB(255, 100, 80),
			action = "enterArena",
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			desc = "Wähle deinen Nova Blader",
			position = Vector3.new(25, 0, -20),
			size = Vector3.new(12, 8, 4),
			color = Color3.fromRGB(80, 140, 255),
			action = "openBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			desc = "Statistiken & Bestenliste",
			position = Vector3.new(0, 0, 25),
			size = Vector3.new(20, 8, 6),
			color = Color3.fromRGB(255, 200, 60),
			action = "showStats",
		},
	},
}

return HubConfig
