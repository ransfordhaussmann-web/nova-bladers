local HubConfig = {
	HUB_FOLDER = "NovaHub",
	ORIGIN = Vector3.new(0, 0, 200),
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 16,
	SPAWN_OFFSET = Vector3.new(0, 3, -45),

	FLOOR_COLOR = Color3.fromRGB(35, 40, 55),
	WALL_COLOR = Color3.fromRGB(50, 55, 75),
	ACCENT_COLOR = Color3.fromRGB(80, 140, 255),

	ZONES = {
		ArenaGate = {
			name = "Arena-Tor",
			hint = "Drücke E — in die Arena!",
			position = Vector3.new(0, 0, 48),
			size = Vector3.new(22, 1, 14),
			color = Color3.fromRGB(220, 80, 60),
			action = "enterArena",
			promptText = "Arena betreten",
		},
		BeyLab = {
			name = "Bey-Labor",
			hint = "Drücke E — Bey wählen!",
			position = Vector3.new(-42, 0, 0),
			size = Vector3.new(18, 1, 18),
			color = Color3.fromRGB(80, 180, 120),
			action = "openBeySelect",
			promptText = "Bey auswählen",
		},
		HallOfFame = {
			name = "Ruhmeshalle",
			hint = "Top 5 Spieler",
			position = Vector3.new(42, 0, 0),
			size = Vector3.new(18, 1, 18),
			color = Color3.fromRGB(255, 200, 60),
			action = "showLeaderboard",
			promptText = "Rangliste ansehen",
		},
	},

	ARENA_SPAWN_NAMES = { "Spawn", "ArenaSpawn" },
	LEADERBOARD_REFRESH = 30,
}

return HubConfig
