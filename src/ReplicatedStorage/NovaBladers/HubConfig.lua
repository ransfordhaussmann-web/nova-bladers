local HubConfig = {
	SPAWN = Vector3.new(0, 3.5, -25),
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 12,
	WALL_THICKNESS = 2,
	ZONE_CHECK_INTERVAL = 0.25,

	ZONES = {
		Arena = {
			id = "Arena",
			label = "Arena-Tor",
			hint = "Drücke E um die Arena zu betreten",
			action = "enterArena",
			center = Vector3.new(0, 4, 28),
			size = Vector3.new(22, 8, 12),
			color = Color3.fromRGB(255, 110, 70),
		},
		BeyLab = {
			id = "BeyLab",
			label = "Bey-Labor",
			hint = "Drücke E um deinen Bey zu wählen",
			action = "openBeySelect",
			center = Vector3.new(-32, 4, 0),
			size = Vector3.new(18, 8, 18),
			color = Color3.fromRGB(80, 140, 255),
		},
		HallOfFame = {
			id = "HallOfFame",
			label = "Ruhmeshalle",
			hint = "Top-Spieler ansehen",
			action = "viewLeaderboard",
			center = Vector3.new(32, 4, 0),
			size = Vector3.new(18, 8, 18),
			color = Color3.fromRGB(255, 200, 60),
		},
	},
}

return HubConfig
