local HubConfig = {
	SPAWN_POSITION = Vector3.new(0, 3.5, -25),

	FLOOR_SIZE = Vector3.new(120, 1, 120),
	FLOOR_Y = 0,
	WALL_HEIGHT = 24,

	THEME = {
		floor = Color3.fromRGB(18, 22, 38),
		wall = Color3.fromRGB(28, 34, 58),
		accent = Color3.fromRGB(80, 160, 255),
		trim = Color3.fromRGB(255, 200, 60),
	},

	ZONES = {
		ArenaGate = {
			name = "Arena-Tor",
			hint = "Drücke E — Arena betreten",
			action = "EnterArena",
			position = Vector3.new(0, 0.5, 38),
			size = Vector3.new(22, 1, 14),
			color = Color3.fromRGB(255, 90, 70),
		},
		BeyLab = {
			name = "Bey-Labor",
			hint = "Drücke E — Bey wählen",
			action = "OpenBeySelect",
			position = Vector3.new(-38, 0.5, 0),
			size = Vector3.new(18, 1, 18),
			color = Color3.fromRGB(70, 130, 255),
		},
		HallOfFame = {
			name = "Ruhmeshalle",
			hint = "Globales Leaderboard",
			action = "ViewLeaderboard",
			position = Vector3.new(38, 0.5, 0),
			size = Vector3.new(18, 1, 18),
			color = Color3.fromRGB(255, 190, 50),
		},
	},
}

return HubConfig
