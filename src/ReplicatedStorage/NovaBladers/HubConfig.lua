local HubConfig = {
	HUB_NAME = "NovaHub",
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 12,
	SPAWN_OFFSET = Vector3.new(0, 3, -40),

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Drücke E — Arena betreten",
			action = "enterArena",
			position = Vector3.new(0, 0, 35),
			radius = 10,
			color = Color3.fromRGB(255, 100, 80),
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Drücke E — Bey wählen",
			action = "openBeySelect",
			position = Vector3.new(-35, 0, 0),
			radius = 10,
			color = Color3.fromRGB(80, 140, 255),
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler ansehen",
			action = "viewLeaderboard",
			position = Vector3.new(35, 0, 0),
			radius = 10,
			color = Color3.fromRGB(255, 200, 60),
		},
	},

	ZONE_CHECK_INTERVAL = 0.25,
	ACTION_KEY = Enum.KeyCode.E,
}

return HubConfig
