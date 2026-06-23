local HubConfig = {
	SPAWN_POSITION = Vector3.new(0, 3.5, -25),
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 18,
	WALL_THICKNESS = 2,
	INTERACT_KEY = Enum.KeyCode.E,
	INTERACT_RANGE = 10,

	ZONES = {
		{
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Drücke E — Arena betreten",
			position = Vector3.new(0, 2, 38),
			size = Vector3.new(18, 12, 10),
			color = Color3.fromRGB(255, 120, 60),
			action = "enterArena",
		},
		{
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Drücke E — Bey auswählen",
			position = Vector3.new(-32, 2, 0),
			size = Vector3.new(16, 10, 16),
			color = Color3.fromRGB(80, 140, 255),
			action = "openBeySelect",
		},
		{
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler Rangliste",
			position = Vector3.new(32, 2, 0),
			size = Vector3.new(18, 14, 12),
			color = Color3.fromRGB(255, 200, 80),
			action = "none",
		},
	},
}

return HubConfig
