local HubConfig = {
	SPAWN = Vector3.new(0, 3.5, -25),
	FLOOR_SIZE = Vector2.new(120, 120),
	FLOOR_Y = 0,
	WALL_HEIGHT = 16,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Drücke E um die Arena zu betreten",
			action = "enterArena",
			center = Vector3.new(0, 4, 35),
			size = Vector3.new(20, 10, 12),
			color = Color3.fromRGB(255, 120, 60),
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Drücke E um deinen Bey zu wählen",
			action = "openBeySelect",
			center = Vector3.new(-38, 4, 0),
			size = Vector3.new(16, 10, 16),
			color = Color3.fromRGB(80, 160, 255),
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler der Nova Bladers",
			action = "none",
			center = Vector3.new(38, 4, 0),
			size = Vector3.new(16, 10, 16),
			color = Color3.fromRGB(255, 210, 80),
		},
	},
}

return HubConfig
