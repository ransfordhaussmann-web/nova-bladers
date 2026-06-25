local HubConfig = {
	HUB_FOLDER = "NovaHub",
	SPAWN_POSITION = Vector3.new(0, 3, 0),

	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 12,
	WALL_THICKNESS = 2,

	INTERACT_RADIUS = 10,
	INTERACT_KEY = Enum.KeyCode.E,

	ZONES = {
		{
			id = "arena_gate",
			name = "Arena-Tor",
			hint = "Drücke E — Kampf starten",
			position = Vector3.new(0, 0, -42),
			size = Vector3.new(18, 1, 14),
			color = Color3.fromRGB(255, 90, 70),
			action = "enter_arena",
		},
		{
			id = "bey_lab",
			name = "Bey-Labor",
			hint = "Drücke E — Bey wählen",
			position = Vector3.new(-38, 0, 18),
			size = Vector3.new(14, 1, 14),
			color = Color3.fromRGB(80, 160, 255),
			action = "open_bey_select",
		},
		{
			id = "hall_of_fame",
			name = "Ruhmeshalle",
			hint = "Drücke E — Top-Spieler ansehen",
			position = Vector3.new(38, 0, 18),
			size = Vector3.new(14, 1, 14),
			color = Color3.fromRGB(255, 200, 60),
			action = "show_leaderboard",
		},
	},
}

return HubConfig
