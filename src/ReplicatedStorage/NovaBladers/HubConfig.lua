local HubConfig = {
	HUB_NAME = "NovaHub",
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 16,
	SPAWN_POSITION = Vector3.new(0, 4, -40),
	PROXIMITY_RANGE = 10,

	ZONES = {
		{
			id = "arena_gate",
			name = "Arena-Tor",
			hint = "Drücke E — Arena betreten",
			action = "enter_arena",
			position = Vector3.new(0, 0.5, 45),
			size = Vector3.new(14, 10, 6),
			color = Color3.fromRGB(255, 120, 60),
		},
		{
			id = "bey_lab",
			name = "Bey-Labor",
			hint = "Drücke E — Bey auswählen",
			action = "open_bey_select",
			position = Vector3.new(-40, 0.5, 0),
			size = Vector3.new(12, 10, 12),
			color = Color3.fromRGB(80, 160, 255),
		},
		{
			id = "hall_of_fame",
			name = "Ruhmeshalle",
			hint = "Drücke E — Rangliste ansehen",
			action = "show_leaderboard",
			position = Vector3.new(40, 0.5, 0),
			size = Vector3.new(12, 10, 12),
			color = Color3.fromRGB(255, 200, 80),
		},
	},
}

return HubConfig
