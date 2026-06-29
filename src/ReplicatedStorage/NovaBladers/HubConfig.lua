local HubConfig = {
	ORIGIN = Vector3.new(0, 8, 220),
	PLATFORM_RADIUS = 42,
	PLATFORM_HEIGHT = 2,

	SPAWN_POINTS = {
		Vector3.new(-8, 0, 8),
		Vector3.new(8, 0, 8),
		Vector3.new(0, 0, -6),
		Vector3.new(-12, 0, -4),
		Vector3.new(12, 0, -4),
	},

	ZONES = {
		ArenaGate = {
			offset = Vector3.new(0, 0, -32),
			size = Vector3.new(14, 10, 6),
			label = "Arena-Tor",
			hint = "Betrete das Tor, um zu kämpfen!",
		},
		Leaderboard = {
			offset = Vector3.new(18, 0, 12),
			size = Vector3.new(8, 8, 4),
			label = "Rangliste",
			hint = "Top-Spieler der Nova Liga",
		},
		BeyShowcase = {
			offset = Vector3.new(-18, 0, 12),
			size = Vector3.new(10, 8, 6),
			label = "Bey-Schaukasten",
			hint = "Wähle deinen Bey vor dem Kampf",
		},
	},

	ARENA_SPAWN = Vector3.new(0, 6, 0),
	GATE_COOLDOWN = 2,
}

return HubConfig
