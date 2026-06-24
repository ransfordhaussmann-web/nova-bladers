local HubConfig = {
	HUB_NAME = "NovaHub",
	SPAWN_POSITION = Vector3.new(0, 4, 0),

	FLOOR_SIZE = Vector3.new(72, 1, 72),
	WALL_HEIGHT = 10,
	WALL_THICKNESS = 2,

	ZONE_PROMPT_DISTANCE = 12,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			subtitle = "Match starten",
			position = Vector3.new(0, 0.5, -26),
			size = Vector3.new(18, 1, 14),
			color = Color3.fromRGB(255, 90, 70),
			action = "enterArena",
			prompt = "Arena betreten",
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			subtitle = "Blade wählen",
			position = Vector3.new(-24, 0.5, 8),
			size = Vector3.new(14, 1, 14),
			color = Color3.fromRGB(70, 140, 255),
			action = "beySelect",
			prompt = "Bey auswählen",
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			subtitle = "Top-Spieler",
			position = Vector3.new(24, 0.5, 8),
			size = Vector3.new(14, 1, 14),
			color = Color3.fromRGB(255, 190, 50),
			action = "leaderboard",
			prompt = "Rangliste ansehen",
		},
	},
}

return HubConfig
