local HubConfig = {
	HUB_NAME = "NovaHub",
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	SPAWN_OFFSET = Vector3.new(0, 3, 0),
	WALL_HEIGHT = 12,
	ZONE_RADIUS = 10,

	ZONES = {
		{
			id = "arena_gate",
			name = "Arena-Tor",
			hint = "Drücke E — Arena betreten",
			action = "enter_arena",
			position = Vector3.new(42, 0, 0),
			color = Color3.fromRGB(255, 90, 60),
		},
		{
			id = "bey_lab",
			name = "Bey-Labor",
			hint = "Drücke E — Bey wählen",
			action = "bey_select",
			position = Vector3.new(-38, 0, 28),
			color = Color3.fromRGB(80, 160, 255),
		},
		{
			id = "hall_of_fame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler ansehen",
			action = "leaderboard",
			position = Vector3.new(0, 0, -42),
			color = Color3.fromRGB(255, 200, 60),
		},
	},
}

return HubConfig
