local HubConfig = {
	HUB_FOLDER = "NovaHub",
	HUB_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 16,
	SPAWN_OFFSET = Vector3.new(0, 4, -40),

	ZONES = {
		arena_gate = {
			id = "arena_gate",
			name = "Arena-Tor",
			hint = "Betrete die Spin-Arena",
			actionLabel = "Arena betreten",
			position = Vector3.new(0, 2, 42),
			size = Vector3.new(18, 10, 6),
			color = Color3.fromRGB(255, 120, 60),
			action = "enter_arena",
		},
		bey_lab = {
			id = "bey_lab",
			name = "Bey-Labor",
			hint = "Wähle deinen Bey",
			actionLabel = "Bey auswählen",
			position = Vector3.new(-38, 2, 0),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(80, 160, 255),
			action = "open_bey_select",
		},
		hall_of_fame = {
			id = "hall_of_fame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler der Nova Liga",
			actionLabel = "Rangliste ansehen",
			position = Vector3.new(38, 2, 0),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(255, 210, 80),
			action = "view_leaderboard",
		},
	},

	PROXIMITY_RADIUS = 12,
	LEADERBOARD_BOARD_SIZE = Vector3.new(10, 8, 0.5),
}

return HubConfig
