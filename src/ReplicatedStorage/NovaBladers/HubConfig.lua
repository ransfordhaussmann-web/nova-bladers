local HubConfig = {
	HUB_NAME = "NovaHub",
	SPAWN_OFFSET = Vector3.new(0, 4, 0),
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 14,
	WALL_THICKNESS = 2,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Drücke E — Arena betreten",
			position = Vector3.new(0, 0, -42),
			size = Vector3.new(22, 12, 10),
			color = Color3.fromRGB(220, 70, 70),
			action = "arena",
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Drücke E — Bey wählen",
			position = Vector3.new(-42, 0, 18),
			size = Vector3.new(18, 10, 18),
			color = Color3.fromRGB(70, 130, 255),
			action = "beySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler der Nova Liga",
			position = Vector3.new(42, 0, 18),
			size = Vector3.new(18, 12, 18),
			color = Color3.fromRGB(255, 190, 50),
			action = "leaderboard",
		},
	},
}

return HubConfig
