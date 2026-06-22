local HubConfig = {
	SPAWN = Vector3.new(0, 3, -25),
	FLOOR_SIZE = Vector3.new(120, 1, 80),
	WALL_HEIGHT = 16,
	WALL_THICKNESS = 2,

	ZONES = {
		ArenaGate = {
			id = "arena",
			name = "Arena-Tor",
			hint = "Kampf starten",
			position = Vector3.new(0, 0, 32),
			size = Vector3.new(22, 10, 12),
			color = Color3.fromRGB(255, 90, 70),
			action = "enterArena",
			promptText = "Kampf starten",
		},
		BeyLab = {
			id = "bey",
			name = "Bey-Labor",
			hint = "Bey auswählen",
			position = Vector3.new(-42, 0, 0),
			size = Vector3.new(16, 10, 16),
			color = Color3.fromRGB(70, 150, 255),
			action = "openBeySelect",
			promptText = "Bey wählen",
		},
		HallOfFame = {
			id = "leaderboard",
			name = "Ruhmeshalle",
			hint = "Top-Spieler ansehen",
			position = Vector3.new(42, 0, 0),
			size = Vector3.new(16, 10, 16),
			color = Color3.fromRGB(255, 190, 50),
			action = "showLeaderboard",
			promptText = "Rangliste",
		},
	},

	LEADERBOARD_BOARD_SIZE = Vector2.new(600, 400),
	ARENA_FALLBACK = CFrame.new(0, 5, 0),
}

return HubConfig
