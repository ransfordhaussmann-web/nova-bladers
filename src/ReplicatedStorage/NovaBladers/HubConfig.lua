local HubConfig = {
	SPAWN_CFRAME = CFrame.new(0, 3.5, -25),
	FLOOR_SIZE = Vector3.new(80, 1, 60),
	WALL_HEIGHT = 14,
	WALL_THICKNESS = 2,

	COLORS = {
		FLOOR = Color3.fromRGB(35, 40, 55),
		WALL = Color3.fromRGB(50, 55, 75),
		ACCENT = Color3.fromRGB(100, 160, 255),
	},

	ZONES = {
		{
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Drücke [E] um die Arena zu betreten",
			action = "enterArena",
			cframe = CFrame.new(0, 4, 22),
			size = Vector3.new(16, 10, 8),
			color = Color3.fromRGB(255, 100, 50),
		},
		{
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Drücke [E] um deinen Bey zu wählen",
			action = "openBeySelect",
			cframe = CFrame.new(-22, 4, 0),
			size = Vector3.new(12, 10, 12),
			color = Color3.fromRGB(70, 130, 255),
		},
		{
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler der Arena",
			action = "none",
			cframe = CFrame.new(22, 4, 0),
			size = Vector3.new(12, 10, 12),
			color = Color3.fromRGB(255, 190, 50),
		},
	},

	LEADERBOARD = {
		cframe = CFrame.new(24, 7, 0) * CFrame.Angles(0, math.rad(-90), 0),
		size = Vector3.new(10, 6, 0.5),
		topCount = 5,
	},

	ARENA_SPAWN_FALLBACK = CFrame.new(0, 5, 0),
}

return HubConfig
