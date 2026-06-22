local HubConfig = {
	SPAWN_POSITION = Vector3.new(0, 4, 200),
	HUB_SIZE = Vector2.new(120, 80),
	WALL_HEIGHT = 16,
	FLOOR_THICKNESS = 2,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Drücke E um die Arena zu betreten",
			position = Vector3.new(0, 0, 160),
			size = Vector3.new(20, 12, 8),
			color = Color3.fromRGB(255, 120, 80),
			action = "enterArena",
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Drücke E um deinen Bey zu wählen",
			position = Vector3.new(-35, 0, 200),
			size = Vector3.new(16, 10, 16),
			color = Color3.fromRGB(80, 140, 255),
			action = "openBeySelect",
		},
		FameHall = {
			id = "FameHall",
			name = "Ruhmeshalle",
			hint = "Globales Leaderboard",
			position = Vector3.new(35, 0, 200),
			size = Vector3.new(16, 10, 16),
			color = Color3.fromRGB(255, 200, 60),
			action = "showLeaderboard",
		},
	},
}

return HubConfig
