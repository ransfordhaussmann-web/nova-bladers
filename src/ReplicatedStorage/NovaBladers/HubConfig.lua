local HubConfig = {
	HUB_NAME = "NovaHub",
	SPAWN_POSITION = Vector3.new(0, 4, 0),
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 16,
	WALL_THICKNESS = 2,

	ZONES = {
		{
			id = "arena_gate",
			name = "Arena-Tor",
			hint = "Drücke E um in die Arena zu gehen",
			position = Vector3.new(0, 2, -45),
			radius = 10,
			action = "enter_arena",
			color = Color3.fromRGB(255, 100, 80),
		},
		{
			id = "bey_lab",
			name = "Bey-Labor",
			hint = "Drücke E um deinen Bey auszuwählen",
			position = Vector3.new(-40, 2, 20),
			radius = 10,
			action = "open_bey_select",
			color = Color3.fromRGB(80, 160, 255),
		},
		{
			id = "hall_of_fame",
			name = "Ruhmeshalle",
			hint = "Drücke E für Statistiken & Leaderboard",
			position = Vector3.new(40, 2, 20),
			radius = 10,
			action = "show_lobby",
			color = Color3.fromRGB(255, 200, 60),
		},
	},
}

return HubConfig
