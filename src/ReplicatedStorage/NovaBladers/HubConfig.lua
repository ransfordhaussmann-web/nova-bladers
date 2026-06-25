local HubConfig = {
	ORIGIN = Vector3.new(0, 0, 0),
	FLOOR_SIZE = Vector2.new(120, 120),
	WALL_HEIGHT = 14,
	SPAWN = CFrame.new(0, 3, 42),
	ARENA_SPAWN = CFrame.new(0, 3, -55),

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			prompt = "E — Arena betreten",
			position = Vector3.new(0, 0, -38),
			radius = 9,
			action = "enterArena",
			color = Color3.fromRGB(255, 90, 60),
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			prompt = "E — Bey wählen",
			position = Vector3.new(-36, 0, 0),
			radius = 8,
			action = "openBeySelect",
			color = Color3.fromRGB(80, 140, 255),
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			prompt = "E — Rangliste ansehen",
			position = Vector3.new(36, 0, 0),
			radius = 8,
			action = "viewLeaderboard",
			color = Color3.fromRGB(255, 200, 60),
		},
	},
}

return HubConfig
