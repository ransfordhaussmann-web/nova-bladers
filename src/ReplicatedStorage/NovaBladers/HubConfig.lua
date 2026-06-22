local HubConfig = {
	SPAWN = Vector3.new(0, 3, -25),
	FLOOR_SIZE = Vector3.new(80, 1, 80),
	WALL_HEIGHT = 12,
	WALL_THICKNESS = 2,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Drücke E um die Arena zu betreten",
			action = "enterArena",
			center = Vector3.new(0, 2, 22),
			size = Vector3.new(14, 8, 14),
			color = Color3.fromRGB(255, 120, 80),
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Drücke E um deinen Bey zu wechseln",
			action = "openBeySelect",
			center = Vector3.new(-28, 2, 0),
			size = Vector3.new(12, 8, 12),
			color = Color3.fromRGB(80, 160, 255),
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler der Arena",
			action = "none",
			center = Vector3.new(28, 2, 0),
			size = Vector3.new(12, 8, 12),
			color = Color3.fromRGB(255, 210, 80),
		},
	},

	LEADERBOARD_TOP = 5,
}

return HubConfig
