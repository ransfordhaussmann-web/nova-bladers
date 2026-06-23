local HubConfig = {
	SPAWN = CFrame.new(0, 3.5, -25),

	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 16,
	FLOOR_COLOR = Color3.fromRGB(45, 48, 58),
	WALL_COLOR = Color3.fromRGB(32, 34, 42),

	ARENA_FALLBACK = CFrame.new(0, 5, 0),

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Drücke E, um die Arena zu betreten.",
			action = "EnterArena",
			position = Vector3.new(0, 2, 35),
			size = Vector3.new(18, 8, 12),
			color = Color3.fromRGB(255, 100, 80),
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Drücke E, um deinen Nova Blader zu wählen.",
			action = "OpenBeySelect",
			position = Vector3.new(-40, 2, 0),
			size = Vector3.new(14, 8, 14),
			color = Color3.fromRGB(80, 140, 255),
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler der Nova Bladers.",
			action = "ViewLeaderboard",
			position = Vector3.new(40, 2, 0),
			size = Vector3.new(14, 8, 14),
			color = Color3.fromRGB(255, 200, 60),
		},
	},
}

return HubConfig
