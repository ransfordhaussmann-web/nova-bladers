local HubConfig = {
	SPAWN = Vector3.new(0, 3.5, -25),
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 12,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Betrete die Spin-Arena",
			actionLabel = "[E] Arena betreten",
			position = Vector3.new(0, 1, 35),
			size = Vector3.new(20, 8, 12),
			color = Color3.fromRGB(255, 100, 80),
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Wähle deinen Bey",
			actionLabel = "[E] Bey wählen",
			position = Vector3.new(-40, 1, 0),
			size = Vector3.new(16, 8, 16),
			color = Color3.fromRGB(80, 160, 255),
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler",
			actionLabel = "[E] Rangliste ansehen",
			position = Vector3.new(40, 1, 0),
			size = Vector3.new(16, 8, 16),
			color = Color3.fromRGB(255, 200, 60),
		},
	},

	HINT_RANGE = 14,
	ARENA_FALLBACK_SPAWN = Vector3.new(0, 5, 0),
}

return HubConfig
