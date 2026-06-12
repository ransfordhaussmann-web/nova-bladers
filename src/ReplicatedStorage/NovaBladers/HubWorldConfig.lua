local HubWorldConfig = {
	HUB_ORIGIN = Vector3.new(0, 0, 120),
	FLOOR_SIZE = Vector3.new(80, 1, 80),
	SPAWN_OFFSET = Vector3.new(0, 4, 0),

	ARENA_ENTRY_OFFSET = Vector3.new(0, 6, 0),

	ZONES = {
		Arena = {
			id = "Arena",
			label = "Arena",
			hint = "Betreten zum Kämpfen",
			offset = Vector3.new(0, 0.5, -28),
			size = Vector3.new(18, 1, 18),
			color = Color3.fromRGB(255, 90, 90),
		},
		BeySelect = {
			id = "BeySelect",
			label = "Bey-Auswahl",
			hint = "Wähle deinen Bey",
			offset = Vector3.new(-28, 0.5, 12),
			size = Vector3.new(14, 1, 14),
			color = Color3.fromRGB(80, 140, 255),
		},
		Leaderboard = {
			id = "Leaderboard",
			label = "Rangliste",
			hint = "Top-Spieler ansehen",
			offset = Vector3.new(28, 0.5, 12),
			size = Vector3.new(14, 1, 14),
			color = Color3.fromRGB(255, 200, 60),
		},
	},
}

return HubWorldConfig
