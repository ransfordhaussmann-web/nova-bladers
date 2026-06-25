local HubConfig = {
	HUB_NAME = "NovaHub",
	SPAWN_POSITION = Vector3.new(0, 4, 8),
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 16,
	WALL_THICKNESS = 2,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Drücke E — Kampf starten",
			position = Vector3.new(0, 0, -45),
			size = Vector3.new(24, 12, 16),
			color = Color3.fromRGB(255, 90, 70),
			action = "arena",
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Drücke E — Bey auswählen",
			position = Vector3.new(-42, 0, 15),
			size = Vector3.new(20, 10, 20),
			color = Color3.fromRGB(80, 160, 255),
			action = "beySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Deine Stats & Leaderboard",
			position = Vector3.new(42, 0, 15),
			size = Vector3.new(20, 10, 20),
			color = Color3.fromRGB(255, 200, 60),
			action = "stats",
		},
	},

	INTERACT_DISTANCE = 10,
}

return HubConfig
